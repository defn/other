// Package k3d generates self-contained k3d cluster brick directories.
// Each k3d/{dir}/ contains: BUILD.bazel, cluster.cue, .gitignore,
// main.tf (IRSA tofu), apps.yaml (ArgoCD applications).
// bootstrap.yaml is synced by buildsync from Bazel output.
package k3d

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// Run generates k3d/<dir>/ files for each cluster.
func Run(ctx *gen.Context) error {
	val, err := ctx.LoadCUEPackage("./kernel/interface/k3d", []string{
		"k3s_version=0", "cluster_name=0", "api_port=0",
		"version_var=0", "version_bzl=0", "path=0",
		"account_id=0", "irsa_region=0", "irsa_role_prefix=0",
		"aws_profile=0", "aws_region=0", "has_bootstrap=0", "has_irsa=0",
		"cluster_domain=0", "dns_zone=0",
	})
	if err != nil {
		return fmt.Errorf("load interface/k3d: %w", err)
	}
	clusters := val.LookupPath(cue.ParsePath("clusters"))

	// Load catalog data
	state := ctx.CatalogQuery("aws_state")
	accountID, _ := gen.DecodeString(state, "account_id")
	stateRegion, _ := gen.DecodeString(state, "region")
	stateBucket, _ := gen.DecodeString(state, "bucket")
	// Master AWS profile lives in the tenant overlay's auth.tofu;
	// AIDR-00101 split this off from aws_state.profile so the profile
	// name flows from a dedicated catalog slot. A fork retargets
	// every per-cluster main.tf / mise.toml / BUILD.bazel by editing
	// tenant/<name>/catalog/auth.cue alone.
	authTofu, _ := gen.DecodeString(ctx.CatalogQuery("auth"), "tofu")

	environments := ctx.CatalogQuery("environments")
	platforms := ctx.CatalogQuery("k8s_platforms")
	versions := ctx.CatalogQuery("chart_versions")
	appsCatalog := ctx.CatalogQuery("apps")

	if err := gen.IterMap(clusters, func(_ string, v cue.Value) error {
		clusterName, _ := gen.DecodeString(v, "cluster_name")
		dir, _ := gen.DecodeString(v, "dir")
		versionVar, _ := gen.DecodeString(v, "version_var")
		apiPort, _ := gen.DecodeString(v, "api_port")
		path, _ := gen.DecodeString(v, "path")
		irsaRegion := gen.DecodeStringOr(v, "irsa_region", stateRegion)
		irsaRolePrefix := gen.DecodeStringOr(v, "irsa_role_prefix", "defn-tmp-")
		clusterDomain := gen.DecodeStringOr(v, "cluster_domain", "")
		dnsZone := gen.DecodeStringOr(v, "dns_zone", "")

		versionBzl := strings.ToLower(strings.TrimSuffix(versionVar, "_VERSION"))
		dirPath := path
		if dirPath == "" {
			// Fallback: derive from default_tenant (a fork's catalog
			// flips this without touching code). See AIDR-00071.
			dirPath = "tenant/" + ctx.DefaultTenant() + "/k3d/" + dir
		}

		// Ensure directory and .kube exist
		os.MkdirAll(filepath.Join(ctx.WorkDir, dirPath, ".kube"), 0o755)

		// Look up the environment for this cluster
		envVal := environments.LookupPath(cue.ParsePath(fmt.Sprintf("%q", clusterName)))
		server := gen.DecodeStringOr(envVal, "server", "https://kubernetes.default.svc")
		registry := gen.DecodeStringOr(envVal, "registry", "host.k3d.internal:5000")

		// Determine if this env has argocd (for bootstrap.yaml)
		hasArgocd := false
		platformsField := envVal.LookupPath(cue.ParsePath("platforms"))
		gen.IterMap(platformsField, func(pKey string, _ cue.Value) error {
			pName := gen.CueFieldKey(pKey)
			p := platforms.LookupPath(cue.ParsePath(fmt.Sprintf("%q", pName)))
			appsField := p.LookupPath(cue.ParsePath("apps"))
			gen.IterMap(appsField, func(aKey string, _ cue.Value) error {
				if gen.CueFieldKey(aKey) == "argocd" {
					hasArgocd = true
				}
				return nil
			})
			return nil
		})

		hasBootstrap := "false"
		if hasArgocd {
			hasBootstrap = "true"
		}

		// has_irsa reflects whether the per-cluster tofu state has been
		// applied AND committed (irsa.cue tracked in git). Driven off
		// the file's presence on disk; the operator commits it after
		// `tofu apply`. Without this, the BUILD.bazel `cmd` strings for
		// IRSA-aware apps would bake in workstation-local irsa.cue
		// values and `mise run check` would diverge across workstations.
		// See AIDR-00125.
		hasIRSA := "false"
		if _, err := os.Stat(filepath.Join(ctx.WorkDir, dirPath, "irsa.cue")); err == nil {
			hasIRSA = "true"
		}

		// Stamp BUILD.bazel, cluster.cue, .gitignore from k3d templates
		tags := map[string]string{
			"cluster_name":     clusterName,
			"api_port":         apiPort,
			"k3s_version":      "0",
			"version_var":      versionVar,
			"version_bzl":      versionBzl,
			"path":             path,
			"account_id":       accountID,
			"irsa_region":      irsaRegion,
			"irsa_role_prefix": irsaRolePrefix,
			"aws_profile":      authTofu,
			"aws_region":       stateRegion,
			"cluster_domain":   clusterDomain,
			"dns_zone":         dnsZone,
			"has_bootstrap":    hasBootstrap,
			"has_irsa":         hasIRSA,
		}

		if err := ctx.StampFromCUE(
			"kernel/interface/k3d/templates.cue", dirPath, tags,
			[]gen.StampFile{
				{Field: "build_bazel", Filename: "BUILD.bazel"},
				{Field: "cluster_cue", Filename: "cluster.cue"},
				{Field: "k3d_gitignore", Filename: ".gitignore"},
			},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", dirPath, err)
		}

		// Stamp IRSA tofu main.tf from aws templates. state_profile
		// and profile both come from auth.tofu (the master org SSO
		// profile) -- aws_state.profile happens to share that value
		// today, but auth.tofu is the source of truth post-AIDR-00101.
		irsaTags := map[string]string{
			"cluster_name":     clusterName,
			"cluster_dir":      dir,
			"irsa_role_prefix": irsaRolePrefix,
			"state_profile":    authTofu,
			"state_account_id": accountID,
			"state_bucket":     stateBucket,
			"state_region":     stateRegion,
			"profile":          authTofu,
			"region":           irsaRegion,
			"has_lock":         hasLock(ctx, dirPath),
			"module_depth":     "../../../..",
		}
		if err := ctx.StampFromCUE(
			"kernel/interface/aws/templates.cue", dirPath, irsaTags,
			[]gen.StampFile{
				{Field: "irsa_main_tf", Filename: "main.tf"},
			},
		); err != nil {
			return fmt.Errorf("stamp %s main.tf: %w", dirPath, err)
		}

		// Generate apps.yaml
		if err := genAppsYAML(ctx, clusterName, dirPath, envVal, platforms, versions, appsCatalog, server, registry); err != nil {
			return fmt.Errorf("gen apps.yaml for %s: %w", clusterName, err)
		}

		ctx.LogOK(fmt.Sprintf("generated %s/", dirPath))
		return nil
	}); err != nil {
		return fmt.Errorf("iterate clusters: %w", err)
	}
	return nil
}

// genAppsYAML generates the ArgoCD apps.yaml for a k3d cluster environment.
func genAppsYAML(ctx *gen.Context, envName, dirPath string, envVal cue.Value, platforms, versions, appsCatalog cue.Value, server, registry string) error {
	type appInfo struct {
		name      string
		namespace string
	}
	combinedApps := map[string]appInfo{}
	platformsField := envVal.LookupPath(cue.ParsePath("platforms"))
	gen.IterMap(platformsField, func(pKey string, _ cue.Value) error {
		pName := gen.CueFieldKey(pKey)
		p := platforms.LookupPath(cue.ParsePath(fmt.Sprintf("%q", pName)))
		appsField := p.LookupPath(cue.ParsePath("apps"))
		gen.IterMap(appsField, func(aKey string, aConf cue.Value) error {
			k := gen.CueFieldKey(aKey)
			defaultNS := k
			if strings.HasSuffix(k, "-crds") {
				defaultNS = "default"
			}
			ns := gen.DecodeStringOr(aConf, "namespace", defaultNS)
			combinedApps[k] = appInfo{name: k, namespace: ns}
			return nil
		})
		return nil
	})

	var appNames []string
	for k := range combinedApps {
		appNames = append(appNames, k)
	}
	sort.Strings(appNames)

	if len(appNames) == 0 {
		return nil
	}

	var yamls []string
	for _, appName := range appNames {
		ai := combinedApps[appName]
		version := gen.DecodeStringOr(
			versions.LookupPath(cue.ParsePath(
				fmt.Sprintf(`"%s".cluster_digests."%s"`, appName, envName))),
			"version", "0.0.1")
		wave := syncWave(appName)

		// Every chart is published per-cluster.
		chartPath := envName + "/" + appName

		// Ignore controller-injected fields that cause permanent OutOfSync
		var ignoreDiffEntries []string
		if strings.HasSuffix(appName, "-crds") {
			ignoreDiffEntries = append(ignoreDiffEntries,
				"    - group: apiextensions.k8s.io\n"+
					"      kind: CustomResourceDefinition\n"+
					"      jqPathExpressions:\n"+
					"        - .spec.conversion")
		}
		// ExternalSecret finalizers (added by ESO controller)
		ignoreDiffEntries = append(ignoreDiffEntries,
			"    - group: external-secrets.io\n"+
				"      kind: ExternalSecret\n"+
				"      jqPathExpressions:\n"+
				"        - .metadata.finalizers")
		// Service finalizers (added by tailscale operator)
		ignoreDiffEntries = append(ignoreDiffEntries,
			"    - kind: Service\n"+
				"      jqPathExpressions:\n"+
				"        - .metadata.finalizers")
		// ClusterPolicy status (added by Kyverno controller)
		ignoreDiffEntries = append(ignoreDiffEntries,
			"    - group: kyverno.io\n"+
				"      kind: ClusterPolicy\n"+
				"      jqPathExpressions:\n"+
				"        - .status")
		// Webhook caBundle (injected by cert-manager)
		ignoreDiffEntries = append(ignoreDiffEntries,
			"    - group: admissionregistration.k8s.io\n"+
				"      kind: MutatingWebhookConfiguration\n"+
				"      jqPathExpressions:\n"+
				"        - .webhooks[].clientConfig.caBundle")
		ignoreDiffEntries = append(ignoreDiffEntries,
			"    - group: admissionregistration.k8s.io\n"+
				"      kind: ValidatingWebhookConfiguration\n"+
				"      jqPathExpressions:\n"+
				"        - .webhooks[].clientConfig.caBundle")
		// Kruise controller actively reconciles webhook configs: injects
		// caBundle, adds template annotation, and prunes webhooks for
		// disabled feature gates. Ignore the entire webhooks array and
		// the kruise-managed template annotation.
		if appName == "kruise" {
			ignoreDiffEntries = append(ignoreDiffEntries,
				"    - group: admissionregistration.k8s.io\n"+
					"      kind: MutatingWebhookConfiguration\n"+
					"      jqPathExpressions:\n"+
					"        - .webhooks\n"+
					"        - .metadata.annotations.template")
			ignoreDiffEntries = append(ignoreDiffEntries,
				"    - group: admissionregistration.k8s.io\n"+
					"      kind: ValidatingWebhookConfiguration\n"+
					"      jqPathExpressions:\n"+
					"        - .webhooks\n"+
					"        - .metadata.annotations.template")
		}
		// vcluster chart bakes a config hash into the StatefulSet that
		// won't match when the config secret is managed by ESO.
		if appName == "vcluster" {
			ignoreDiffEntries = append(ignoreDiffEntries,
				"    - group: apps\n"+
					"      kind: StatefulSet\n"+
					"      jqPathExpressions:\n"+
					"        - .spec.template.metadata.annotations.vClusterConfigHash")
		}
		ignoreDiffs := "\n  ignoreDifferences:\n" + strings.Join(ignoreDiffEntries, "\n")

		yamls = append(yamls, fmt.Sprintf(
			"apiVersion: argoproj.io/v1alpha1\n"+
				"kind: Application\n"+
				"metadata:\n"+
				"  name: %s--%s\n"+
				"  namespace: argocd\n"+
				"  annotations:\n"+
				"    argocd.argoproj.io/sync-wave: \"%s\"\n"+
				"spec:\n"+
				"  project: default\n"+
				"  source:\n"+
				"    repoURL: oci://%s/rendered-manifests/%s\n"+
				"    chart: %s\n"+
				"    targetRevision: \"%s\"\n"+
				"  destination:\n"+
				"    server: %s\n"+
				"    namespace: %s%s\n"+
				"  syncPolicy:\n"+
				"    automated:\n"+
				"      prune: true\n"+
				"      selfHeal: true\n"+
				"    retry:\n"+
				"      limit: -1\n"+
				"      backoff:\n"+
				"        duration: 5s\n"+
				"        maxDuration: 3m\n"+
				"        factor: 2\n"+
				"    syncOptions:\n"+
				"      - ServerSideApply=true\n"+
				"      - SkipDryRunOnMissingResource=true\n"+
				"      - RespectIgnoreDifferences=true",
			envName, appName, wave, registry, chartPath, appName, version, server, ai.namespace, ignoreDiffs))
	}

	content := "# Generated by defn gen -- DO NOT EDIT.\n" +
		"# Run: mise run gen\n" +
		"#\n" +
		"# App-of-apps: kubectl apply -f apps.yaml\n" +
		"---\n" +
		strings.Join(yamls, "\n---\n") + "\n"

	filename := filepath.Join(ctx.WorkDir, dirPath, "apps.yaml")
	_, err := gen.WriteIfChanged(filename, []byte(content), 0o644)
	return err
}

func syncWave(appName string) string {
	if strings.HasSuffix(appName, "-crds") {
		return "0"
	}
	switch appName {
	// Wave 1: cert-manager (TLS for webhooks)
	case "cert-manager":
		return "1"
	// Wave 2: need cert-manager
	case "capsule":
		return "2"
	case "trust-manager":
		return "2"
	// Wave 3: needs capsule
	case "capsule-tenants":
		return "3"
	// Wave 4: need CRDs + cert-manager
	case "ack-iam":
		return "4"
	case "external-secrets":
		return "4"
	// Wave 5: needs ack-iam running
	case "aws-irsa-roles":
		return "5"
	// Wave 6: needs IRSA roles from wave 5
	case "aws-secret-store":
		return "6"
	// Wave 7: kyverno after secrets infra is ready
	case "kyverno":
		return "7"
	// Wave 9: cert issuer (needs cloudflare secret for DNS01); dex
	// (oauth2-proxy depends on dex's OIDC discovery -- AIDR-00120
	// review of AIDR-00114 surfaced the wave inversion bug where
	// oauth2-proxy at wave 10 crashlooped against a missing dex)
	case "letsencrypt-issuer":
		return "9"
	case "dex":
		return "9"
	// Wave 10: ingress + auth (needs certs + secrets + dex)
	case "traefik":
		return "10"
	case "oauth2-proxy":
		return "10"
	// Wave 100: everything else
	default:
		return "100"
	}
}

func hasLock(ctx *gen.Context, dirPath string) string {
	lockFile := filepath.Join(ctx.WorkDir, dirPath, ".terraform.lock.hcl")
	if _, err := os.Stat(lockFile); err == nil {
		return "true"
	}
	return "false"
}
