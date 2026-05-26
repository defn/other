// Package app generates app BUILD.bazel files and capsule-tenants gen-app.cue.
package app

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/golib"
)

// blankLineRun matches 3+ consecutive newlines. When the CUE template
// assembles raw_cluster_build_bazel and cluster_entries is empty (a
// fork with no clusters referencing the app), the concatenated
// separators leave 3+ \n in a row which buildifier rejects. Collapse
// to two newlines (= one blank line) before writing.
var blankLineRun = regexp.MustCompile(`\n{3,}`)

type appData struct {
	name         string
	kind         string
	path         string
	desc         string
	chartName    string
	chartVersion string            // helm chart version (e.g. "2.2.9")
	chartVer     string            // OCI publishing version, single-value form (any cluster's value -- used for non-cluster-scoped attrs)
	chartVers    map[string]string // OCI publishing version per cluster (key = cluster name)
	chartSHA     string
	k8sVerDir    string
}

type clusterCtx struct {
	name            string
	dir             string
	accountID       string
	rolePrefix      string
	irsaRegion      string
	oidcProviderARN string
	oidcIssuerHost  string
	clusterDomain   string
	dnsZone         string
	acmeEndpoint    string // "prod" (default) or "staging" for the per-cluster Let's Encrypt directory
	k8sVerDir       string // e.g. "k8s-c", keyed by cluster letter
}

type irsaOverlay struct {
	workload       string
	deploymentName string
	containerName  string
	saName         string
	namespace      string
	domainPatch    bool
	// Tailscale expose: Service name and namespace to annotate with hostname
	tailscaleSvc string
	tailscaleNS  string
}

type verDir struct {
	dirName   string
	verString string
}

type mirrorEntry struct {
	source string
	tag    string
}

// Run generates app/<name>/BUILD.bazel and app/capsule-tenants/gen-app.cue.
func Run(ctx *gen.Context) error {
	// Load from CUE (sequential -- shared context)
	appVal, err := ctx.LoadCUEPackage("./kernel/interface/app", nil)
	if err != nil {
		return fmt.Errorf("load interface/app: %w", err)
	}
	apps := appVal.LookupPath(cue.ParsePath("apps"))
	k8sVersions := appVal.LookupPath(cue.ParsePath("k8s_versions"))
	versions := ctx.CatalogQuery("chart_versions")
	platforms := ctx.CatalogQuery("k8s_platforms")

	// Load mirror data for kustomization.yaml generation
	mirrorImages := ctx.CatalogQuery("mirror_images")
	mirrorRegistryVal := ctx.CatalogQuery("mirror_registry")
	mirrorRegistry, _ := mirrorRegistryVal.String()
	if mirrorRegistry == "" {
		mirrorRegistry = "host.k3d.internal:5000"
	}

	// Build source -> (tag, full key) lookup from mirror_images
	// Keys are "source:tag", e.g. "ghcr.io/stakater/reloader:v1.4.14"
	mirrorBySource := map[string]mirrorEntry{}
	gen.IterMap(mirrorImages, func(key string, v cue.Value) error {
		src, _ := gen.DecodeString(v, "source")
		tag, _ := gen.DecodeString(v, "tag")
		if src != "" && tag != "" {
			mirrorBySource[src] = mirrorEntry{source: src, tag: tag}
		}
		return nil
	})

	// Collect IRSA / domain / tailscale overlays and namespaces (sequential).
	// Apps without overlays render with an identity per-cluster overlay.
	irsaOverlays := map[string]irsaOverlay{}
	bootstrapNS := map[string]bool{"argocd": true, "capsule": true}
	allAppNS := map[string]bool{}
	gen.IterMap(platforms, func(_ string, p cue.Value) error {
		gen.IterMap(p.LookupPath(cue.ParsePath("apps")), func(appKey string, appConf cue.Value) error {
			key := gen.CueFieldKey(appKey)
			ns := gen.DecodeStringOr(appConf, "namespace", key)
			if !bootstrapNS[ns] {
				allAppNS[ns] = true
			}
			irsaConf := appConf.LookupPath(cue.ParsePath("irsa"))
			dp := gen.DecodeBoolOr(appConf, "domain_patch", false)
			tsConf := appConf.LookupPath(cue.ParsePath("tailscale_expose"))
			var tsSvc, tsNS string
			if tsConf.Exists() {
				tsSvc, _ = gen.DecodeString(tsConf, "service")
				tsNS, _ = gen.DecodeString(tsConf, "namespace")
			}
			if irsaConf.Exists() || dp || tsConf.Exists() {
				var wl, dn, cn, sn string
				if irsaConf.Exists() {
					wl, _ = gen.DecodeString(irsaConf, "workload")
					dn, _ = gen.DecodeString(irsaConf, "deployment_name")
					cn, _ = gen.DecodeString(irsaConf, "container_name")
					sn, _ = gen.DecodeString(irsaConf, "sa_name")
				}
				irsaOverlays[key] = irsaOverlay{
					workload:       wl,
					deploymentName: dn,
					containerName:  cn,
					saName:         sn,
					namespace:      ns,
					domainPatch:    dp,
					tailscaleSvc:   tsSvc,
					tailscaleNS:    tsNS,
				}
			}
			return nil
		})
		return nil
	})
	var sortedNS []string
	for ns := range allAppNS {
		sortedNS = append(sortedNS, ns)
	}
	sort.Strings(sortedNS)

	// Extract cluster info for per-cluster rendering (sequential)
	var clusters []clusterCtx
	state := ctx.CatalogQuery("aws_state")
	accountID, _ := gen.DecodeString(state, "account_id")
	k3dClusters := ctx.CatalogQuery("k3d_clusters")
	gen.IterMap(k3dClusters, func(_ string, v cue.Value) error {
		cn, _ := gen.DecodeString(v, "cluster_name")
		dir, _ := gen.DecodeString(v, "dir")
		clusterPath := gen.DecodeStringOr(v, "path", "tenant/"+ctx.DefaultTenant()+"/k3d/"+dir)
		rp := gen.DecodeStringOr(v, "irsa_role_prefix", "defn-tmp-")
		ir := gen.DecodeStringOr(v, "irsa_region", "us-east-1")
		// Read OIDC values from <path>/irsa.cue if it exists (written by tofu).
		// Boot tenant has no IRSA, so the file is absent; returns empty strings.
		oidcArn, oidcHost := readIRSACue(ctx, clusterPath)
		cd := gen.DecodeStringOr(v, "cluster_domain", "")
		dz := gen.DecodeStringOr(v, "dns_zone", "")
		acme := gen.DecodeStringOr(v, "acme_endpoint", "prod")
		// k8s version dir is keyed by cluster letter (e.g. "b" -> "k8s-b").
		// Per-cluster k3s pins live in versions.cue; the dir letter is the
		// stable identifier so version bumps don't churn dir names.
		dirLetter := gen.DecodeStringOr(v, "dir", "")
		kvd := "k8s-a" // fallback (cluster a == k3s stable)
		if dirLetter != "" {
			kvd = "k8s-" + dirLetter
		}
		clusters = append(clusters, clusterCtx{
			name: cn, dir: dir, accountID: accountID, rolePrefix: rp,
			irsaRegion: ir, oidcProviderARN: oidcArn, oidcIssuerHost: oidcHost,
			clusterDomain: cd, dnsZone: dz, acmeEndpoint: acme, k8sVerDir: kvd,
		})
		return nil
	})
	sort.Slice(clusters, func(i, j int) bool { return clusters[i].name < clusters[j].name })

	// Extract k8s version dirs (sequential)
	var verDirs []verDir
	gen.IterMap(k8sVersions, func(key string, v cue.Value) error {
		s, _ := v.String()
		verDirs = append(verDirs, verDir{dirName: gen.CueFieldKey(key), verString: s})
		return nil
	})

	// Extract app data into Go structs (sequential)
	var appList []appData
	gen.IterMap(apps, func(key string, v cue.Value) error {
		name, _ := gen.DecodeString(v, "name")
		kind, _ := gen.DecodeString(v, "kind")
		path, _ := gen.DecodeString(v, "path")
		desc := gen.DecodeStringOr(v, "desc", name)
		chartName := gen.DecodeStringOr(v, "chart_name", "")
		chartVersion := gen.DecodeStringOr(v, "chart_version", "")
		// Per-cluster chart versions live under chart_versions[name].cluster_digests[cluster].version
		chartVers := map[string]string{}
		appVerEntry := versions.LookupPath(cue.ParsePath(fmt.Sprintf(`"%s".cluster_digests`, name)))
		gen.IterMap(appVerEntry, func(ck string, cv cue.Value) error {
			chartVers[gen.CueFieldKey(ck)] = gen.DecodeStringOr(cv, "version", "")
			return nil
		})
		// Single-value chartVer for non-cluster-scoped uses (kustomize macro
		// chart_version attr, raw single-tarball path). All clusters share
		// the same value for non-cluster-scoped apps; pick the first key for
		// deterministic output.
		chartVer := ""
		var verKeys []string
		for k := range chartVers {
			verKeys = append(verKeys, k)
		}
		sort.Strings(verKeys)
		if len(verKeys) > 0 {
			chartVer = chartVers[verKeys[0]]
		}
		chartSHA := gen.DecodeStringOr(v, "chart_sha256", "")
		k8sVerDir := gen.DecodeStringOr(v, "k8s_version_dir", "k8s-a")
		appList = append(appList, appData{
			name: name, kind: kind, path: path, desc: desc,
			chartName: chartName, chartVersion: chartVersion,
			chartVer: chartVer, chartVers: chartVers,
			chartSHA: chartSHA, k8sVerDir: k8sVerDir,
		})
		return nil
	})
	sort.Slice(appList, func(i, j int) bool { return appList[i].name < appList[j].name })

	// Generate app brick files and brick_files.bzl
	if err := genAppBricks(ctx, appList); err != nil {
		return err
	}

	// Generate capsule-tenants (sequential, one file)
	if err := genCapsuleTenants(ctx, sortedNS); err != nil {
		return err
	}

	// Bricks whose gen-app.cue is owned by another generator -- don't
	// claim their gen-app.cue here or contracts_vet trips
	// unannouncedShared. awstofu names its bricks
	// "aws-acc-<org>-<account>" or "aws-org-<org>"; operatorcrds has a
	// single hard-coded brick.
	// aws_tofu_apps bricks live under the default tenant's app/ tree
	// (they're the AWS org vending pilot, defn-only today; a fork
	// retargets via catalog.cue's default_tenant). Keep this in
	// sync with awstofu.go's appDir. See AIDR-00071.
	tofuAppBase := "tenant/" + ctx.DefaultTenant() + "/app"
	otherGeneratorOwned := map[string]bool{}
	gen.IterMap(ctx.CatalogQuery("aws_tofu_apps"), func(_ string, v cue.Value) error {
		org, _ := gen.DecodeString(v, "org")
		account, _ := gen.DecodeString(v, "account")
		var brick string
		if account != "" {
			brick = fmt.Sprintf("%s/aws-acc-%s-%s", tofuAppBase, org, account)
		} else {
			brick = fmt.Sprintf("%s/aws-org-%s", tofuAppBase, org)
		}
		otherGeneratorOwned[brick] = true
		return nil
	})
	for _, name := range []string{"terraform-operator-crds"} {
		otherGeneratorOwned["tenant/library/app/"+name] = true
	}

	inputs := make(map[string][]string, len(appList))
	for _, ad := range appList {
		overlay := irsaOverlays[ad.name]
		if err := genApp(ctx, ad, verDirs, clusters, overlay, mirrorBySource, mirrorRegistry); err != nil {
			return err
		}
		brickPath := ad.path
		files, err := collectAppInputs(ctx.WorkDir, brickPath, ad.kind, otherGeneratorOwned[brickPath])
		if err != nil {
			return err
		}
		if len(files) > 0 {
			inputs[brickPath] = files
		}
	}

	// Non-kustomize "raw" apps aren't in catalog.apps but still have
	// hand-written gen-app.cue + sometimes app.cue. Walk app/ to pick
	// them up; any brick not already in inputs that contains gen-app.cue
	// or app.cue counts as a raw app for claim purposes.
	if err := collectRawAppInputs(ctx, inputs, appList, otherGeneratorOwned); err != nil {
		return err
	}

	if err := golib.WriteInputsBlock(ctx, "tenant/library/go/lib/gen/app", "app", "_app_inputs", inputs); err != nil {
		return fmt.Errorf("write inputs block: %w", err)
	}
	return nil
}

// collectAppInputs returns the sorted list of hand-authored files the app
// generator recognizes in an app brick: app.cue, chart tarballs, values*.yaml
// overlays, instance.cue, and (for raw apps) gen-app.cue. BUILD.bazel,
// kustomization.yaml, and kustomize gen-app.cue are generator outputs
// already claimed via the static paths list. When `genAppOwnedElsewhere` is
// true, gen-app.cue is also skipped (claimed by awstofu / operatorcrds).
// rawSourceCue returns the filename of a raw app's hand-written source
// cue file: "raw.cue" after the filename-honesty rename (AIDR-00146),
// else "gen-app.cue" (raw apps whose gen-app.cue is generated --
// capsule-tenants -- or not yet renamed). Detection is by file
// existence so the generator is exception-agnostic: only the truly
// hand-written files get renamed to raw.cue; generated ones keep
// gen-app.cue and this returns that.
func rawSourceCue(workDir, brickPath string) string {
	if _, err := os.Stat(filepath.Join(workDir, brickPath, "raw.cue")); err == nil {
		return "raw.cue"
	}
	return "gen-app.cue"
}

func collectAppInputs(workDir, brickPath, kind string, genAppOwnedElsewhere bool) ([]string, error) {
	dir := filepath.Join(workDir, brickPath)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", brickPath, err)
	}
	var files []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		switch {
		case name == "BUILD.bazel", name == "kustomization.yaml":
			// generator output
		case name == "gen-app.cue" && (kind == "kustomize" || genAppOwnedElsewhere):
			// generator output for kustomize apps, or owned by awstofu / operatorcrds
		case name == "gen-app.cue",
			name == "raw.cue",
			name == "app.cue",
			name == "instance.cue",
			strings.HasSuffix(name, ".tgz"),
			strings.HasPrefix(name, "values") && strings.HasSuffix(name, ".yaml"):
			files = append(files, name)
		}
	}
	sort.Strings(files)
	return files, nil
}

// collectRawAppInputs walks each parent directory of apps in the catalog
// (e.g. "app/", or post-refactor every tenant's "tenant/<t>/app/")
// for brick directories that didn't appear in catalog.apps (the -crds
// companions and a handful of hand-written raws) and claims their
// hand-authored gen-app.cue / app.cue files. Skips directories already
// covered by appList.
func collectRawAppInputs(ctx *gen.Context, inputs map[string][]string, appList []appData, otherGeneratorOwned map[string]bool) error {
	known := make(map[string]bool, len(appList))
	appDirs := map[string]bool{}
	for _, ad := range appList {
		known[ad.path] = true
		if ad.path != "" {
			appDirs[filepath.Dir(ad.path)] = true
		}
	}
	// If the catalog had no apps, there's nothing to walk. Previous
	// versions defaulted to "app/" which no longer exists post-Stage 4
	// (apps live under tenant/<t>/app/). An empty appList means a real
	// configuration problem upstream; let the empty-walk no-op surface
	// it via downstream missingClaims rather than papering over it.
	_ = appDirs
	for appDir := range appDirs {
		entries, err := os.ReadDir(filepath.Join(ctx.WorkDir, appDir))
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return fmt.Errorf("read %s: %w", appDir, err)
		}
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			brickPath := appDir + "/" + e.Name()
			if known[brickPath] {
				continue
			}
			files, err := collectAppInputs(ctx.WorkDir, brickPath, "raw", otherGeneratorOwned[brickPath])
			if err != nil {
				return err
			}
			if len(files) > 0 {
				inputs[brickPath] = files
			}
		}
	}
	return nil
}

func genApp(ctx *gen.Context, ad appData, verDirs []verDir, clusters []clusterCtx, overlay irsaOverlay, mirrorBySource map[string]mirrorEntry, mirrorRegistry string) error {
	dirPath := ad.path
	os.MkdirAll(filepath.Join(ctx.WorkDir, dirPath), 0o755)

	switch ad.kind {
	case "kustomize":
		entries, _ := os.ReadDir(filepath.Join(ctx.WorkDir, dirPath))
		var chartTgz string
		var extraSrcs []string
		for _, e := range entries {
			if strings.HasSuffix(e.Name(), ".tgz") && chartTgz == "" {
				chartTgz = e.Name()
			}
			if strings.HasPrefix(e.Name(), "values") && strings.HasSuffix(e.Name(), ".yaml") {
				extraSrcs = append(extraSrcs, e.Name())
			}
		}
		// AIDR-00146: every kustomize app var-renders. The generated render
		// (gen-app.cue, kustomization.yaml, render-side BUILD.bazel + per-cluster
		// genrules, versioned k8s-* subdirs) lands in var/app/<name>/ (not
		// bundled); only source (app.cue, chart, instance/secrets, dispatch.cue,
		// thin source-side BUILD.bazel) stays at dirPath.
		renderDir := "var/app/" + ad.name
		os.MkdirAll(filepath.Join(ctx.WorkDir, renderDir), 0o755)

		// Generate kustomization.yaml if app.cue exists. app.cue is read from
		// dirPath (source); kustomization.yaml is written to renderDir.
		appCuePath := filepath.Join(ctx.WorkDir, dirPath, "app.cue")
		if _, err := os.Stat(appCuePath); err == nil {
			if err := genKustomizationYAML(ctx, ad, dirPath, renderDir, chartTgz, mirrorBySource, mirrorRegistry); err != nil {
				return fmt.Errorf("gen kustomization.yaml for %s: %w", ad.name, err)
			}
		}

		if chartTgz == "" {
			return fmt.Errorf("no .tgz chart tarball in %s", dirPath)
		}

		var extraSrcsTag string
		if len(extraSrcs) > 0 {
			var quoted []string
			for _, f := range extraSrcs {
				quoted = append(quoted, fmt.Sprintf("%q", f))
			}
			extraSrcsTag = strings.Join(quoted, ", ")
		}

		var optionalArgs string
		// chart_version is no longer passed: the per-cluster genrules own helm
		// chart packaging now (one per cluster, identity overlay when no patches).
		if ad.k8sVerDir != "k8s-a" {
			optionalArgs += fmt.Sprintf("    k8s_version_dir = \"%s\",\n", ad.k8sVerDir)
		}

		// Apps with an app.cue cluster overlay (@tag(cluster_name)) get their
		// app.cue appended per-cluster; the genrule reads it cross-package from
		// the source dir.
		hasAppCueOverlay := false
		if data, err := os.ReadFile(appCuePath); err == nil {
			if strings.Contains(string(data), "@tag(cluster_name)") {
				hasAppCueOverlay = true
			}
		}

		// SOURCE-side BUILD.bazel (dirPath): chart + app.cue + values + dispatch.
		srcContent, err := ctx.StampContent("kernel/interface/app/templates.cue",
			map[string]string{
				"name": ad.name, "path": ad.path,
				"chart_tgz": chartTgz, "chart_sha256": ad.chartSHA,
				"optional_kz_args": "",
				"extra_srcs":       extraSrcsTag,
				"k8s_version":      "0", "ver_dir_name": "0",
				"parent_workspace_path": "0", "version": "0",
			}, "kustomize_source_build_bazel")
		if err != nil {
			return fmt.Errorf("stamp %s: %w", dirPath, err)
		}
		var srcBuf strings.Builder
		srcBuf.WriteString(srcContent + "\n")
		// app.cue + values fmt_test/tagged_file live source-side (files are there).
		if _, err := os.Stat(appCuePath); err == nil {
			fmt.Fprintf(&srcBuf, "\nfmt_test(\n    name = \"app_cue_fmt\",\n    src = \"app.cue\",\n    tool = \"cue\",\n)\n\n")
			fmt.Fprintf(&srcBuf, "tagged_file(\n    name = \"app_cue_tag\",\n    src = \"app.cue\",\n    tags = [\n        \"cue\",\n        \"source\",\n    ],\n)\n")
		}
		for _, vf := range extraSrcs {
			safeName := strings.ReplaceAll(strings.TrimSuffix(vf, ".yaml"), ".", "_")
			fmt.Fprintf(&srcBuf, "\nfmt_test(\n    name = \"%s_yaml_fmt\",\n    src = \"%s\",\n    tool = \"yq\",\n)\n\n", safeName, vf)
			fmt.Fprintf(&srcBuf, "tagged_file(\n    name = \"%s_yaml_tag\",\n    src = \"%s\",\n    tags = [\n        \"config\",\n        \"yaml\",\n    ],\n)\n", safeName, vf)
		}
		srcPath := filepath.Join(ctx.WorkDir, dirPath, "BUILD.bazel")
		if _, err := gen.WriteIfChanged(srcPath, []byte(srcBuf.String()), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", srcPath, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel (source)", dirPath))

		// RENDER-side BUILD.bazel (var/app/<name>): macro + per-cluster genrules.
		renderContent, err := ctx.StampContent("kernel/interface/app/templates.cue",
			map[string]string{
				"name": ad.name, "path": ad.path,
				"chart_tgz": "0", "chart_sha256": "0",
				"optional_kz_args": optionalArgs,
				"render_path":      renderDir,
				"k8s_version":      "0", "ver_dir_name": "0",
				"parent_workspace_path": "0", "version": "0",
			}, "kustomize_render_build_bazel")
		if err != nil {
			return fmt.Errorf("stamp %s: %w", renderDir, err)
		}
		var rndBuf strings.Builder
		rndBuf.WriteString(renderContent + "\n")
		if len(clusters) > 0 {
			appCueLabel := "//" + dirPath + ":app.cue"
			clusterGenrules := renderKustomizeClusterGenrules(ad.name, renderDir, ad.chartVers, ad.k8sVerDir, overlay, clusters, hasAppCueOverlay, appCueLabel)
			fmt.Fprintf(&rndBuf, "\n%s", strings.TrimRight(clusterGenrules, "\n")+"\n")
		}
		renderBuildPath := filepath.Join(ctx.WorkDir, renderDir, "BUILD.bazel")
		os.MkdirAll(filepath.Dir(renderBuildPath), 0o755)
		if _, err := gen.WriteIfChanged(renderBuildPath, []byte(rndBuf.String()), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", renderBuildPath, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel (render)", renderDir))

		// Versioned subdirs -> render dir; chart read from source dir.
		for _, vd := range verDirs {
			verPath := renderDir + "/" + vd.dirName
			os.MkdirAll(filepath.Join(ctx.WorkDir, verPath), 0o755)
			if err := ctx.StampFromCUE("kernel/interface/app/templates.cue", verPath,
				map[string]string{
					"name": ad.name, "path": ad.path,
					"chart_tgz": chartTgz, "chart_sha256": "0",
					"optional_kz_args": "",
					"extra_srcs":       extraSrcsTag,
					"k8s_version":      vd.verString, "ver_dir_name": vd.dirName,
					"parent_workspace_path": renderDir, "parent_source_path": ad.path, "version": "0",
				},
				[]gen.StampFile{{Field: "versioned_build_bazel", Filename: "BUILD.bazel"}},
			); err != nil {
				return fmt.Errorf("stamp %s: %w", verPath, err)
			}
			ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel", verPath))
		}

	case "raw":
		version := ad.chartVer
		if version == "" {
			version = "0.0.1"
		}

		// Every raw app renders per-cluster. Apps with no @tag(cluster_*)
		// produce three byte-identical YAMLs (identity overlay) -- per-cluster
		// just gives every app a uniform place to extend behavior per cluster
		// later without a structural migration.
		declaredTags, hasRawAppCue := detectDeclaredTags(ctx.WorkDir, dirPath)
		cueSrc := rawSourceCue(ctx.WorkDir, dirPath)
		clusterEntries := renderClusterGenrules(ad.name, ad.chartVers, clusters, declaredTags, hasRawAppCue, cueSrc)
		baseContent, err := ctx.StampContent("kernel/interface/app/templates.cue",
			map[string]string{
				"name": ad.name, "path": ad.path,
				"chart_tgz": "0", "chart_sha256": "0",
				"optional_kz_args": "",
				"k8s_version":      "0", "ver_dir_name": "0",
				"parent_workspace_path": "0", "version": version,
				"cluster_entries": clusterEntries,
				"cue_src":         cueSrc,
			}, "raw_cluster_build_bazel")
		if err != nil {
			return fmt.Errorf("stamp %s: %w", dirPath, err)
		}
		var rawBuf strings.Builder
		rawBuf.WriteString(baseContent + "\n")
		if hasRawAppCue {
			fmt.Fprintf(&rawBuf, "\nfmt_test(\n    name = \"app_cue_fmt\",\n    src = \"app.cue\",\n    tool = \"cue\",\n)\n\n")
			fmt.Fprintf(&rawBuf, "tagged_file(\n    name = \"app_cue_tag\",\n    src = \"app.cue\",\n    tags = [\n        \"cue\",\n        \"source\",\n    ],\n)\n")
		}
		buildPath := filepath.Join(ctx.WorkDir, dirPath, "BUILD.bazel")
		os.MkdirAll(filepath.Dir(buildPath), 0o755)
		normalized := blankLineRun.ReplaceAllString(rawBuf.String(), "\n\n")
		if _, err := gen.WriteIfChanged(buildPath, []byte(normalized), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", buildPath, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel", dirPath))
	}
	return nil
}

// readIRSACue reads oidc_provider_arn and oidc_issuer_host from
// <clusterPath>/irsa.cue (e.g. tenant/<owner>/k3d/<cluster>/irsa.cue).
// Returns empty strings if the file doesn't exist (tofu not yet applied
// or the tenant doesn't use IRSA, like boot).
func readIRSACue(ctx *gen.Context, clusterPath string) (string, string) {
	path := filepath.Join(ctx.WorkDir, clusterPath, "irsa.cue")
	data, err := os.ReadFile(path)
	if err != nil {
		return "", ""
	}
	var arn, host string
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "oidc_provider_arn:") {
			arn = strings.Trim(strings.TrimPrefix(line, "oidc_provider_arn:"), " \"")
		}
		if strings.HasPrefix(line, "oidc_issuer_host:") {
			host = strings.Trim(strings.TrimPrefix(line, "oidc_issuer_host:"), " \"")
		}
	}
	return arn, host
}

// renderKustomizeClusterGenrules produces per-cluster Bazel genrules for kustomize apps.
// Each cluster gets: IRSA patch from CUE -> kustomize build (base + patch) -> helm chart.
// versions maps cluster name -> chart version; missing entries default to "0.0.1".
//
// verPkgPath is the Bazel package holding the versioned subdirs whose
// app_kustomize_gen this references -- the app's own path normally, but
// var/app/<name> for AIDR-00146 var-rendered apps. appCueLabel is how the
// per-cluster overlay genrule refers to app.cue: bare "app.cue" when the
// render shares a package with the source, or a cross-package
// "//<source>:app.cue" label when the render is evicted to var/.
func renderKustomizeClusterGenrules(appName, verPkgPath string, versions map[string]string, _ string, overlay irsaOverlay, clusters []clusterCtx, hasAppCueOverlay bool, appCueLabel string) string {
	var sb strings.Builder
	for _, c := range clusters {
		safeName := strings.ReplaceAll(c.name, "-", "_")
		version := versions[c.name]
		if version == "" {
			version = "0.0.1"
		}
		tags := fmt.Sprintf(
			" -t cluster_name=%s -t account_id=%s -t irsa_role_prefix=%s -t irsa_region=%s"+
				" -t workload=%s -t deployment_name=%s -t container_name=%s -t sa_name=%s -t namespace=%s",
			c.name, c.accountID, c.rolePrefix, c.irsaRegion,
			overlay.workload, overlay.deploymentName, overlay.containerName, overlay.saName, overlay.namespace,
		)

		// Build list of patches and their genrules
		hasIRSA := overlay.workload != ""
		hasDomain := overlay.domainPatch

		// Generate IRSA patches if needed
		if hasIRSA {
			fmt.Fprintf(&sb, "# Per-cluster IRSA overlay for %s\n", c.name)
			fmt.Fprintf(&sb, "genrule(\n")
			fmt.Fprintf(&sb, "    name = \"irsa_patch_%s_gen\",\n", safeName)
			fmt.Fprintf(&sb, "    srcs = [\"//kernel/interface/k8s:irsa_patch.cue\"],\n")
			fmt.Fprintf(&sb, "    outs = [\"irsa_patch_%s.yaml\"],\n", safeName)
			fmt.Fprintf(&sb, "    cmd = \"mise x cue@\" + CUE_VERSION +\n")
			fmt.Fprintf(&sb, "          \" -- cue export -e irsa_patch --out yaml\" +\n")
			fmt.Fprintf(&sb, "          \"%s\" +\n", tags)
			fmt.Fprintf(&sb, "          \" $(location //kernel/interface/k8s:irsa_patch.cue) > $@\",\n")
			fmt.Fprintf(&sb, ")\n\n")

			fmt.Fprintf(&sb, "genrule(\n")
			fmt.Fprintf(&sb, "    name = \"irsa_sa_patch_%s_gen\",\n", safeName)
			fmt.Fprintf(&sb, "    srcs = [\"//kernel/interface/k8s:irsa_patch.cue\"],\n")
			fmt.Fprintf(&sb, "    outs = [\"irsa_sa_patch_%s.yaml\"],\n", safeName)
			fmt.Fprintf(&sb, "    cmd = \"mise x cue@\" + CUE_VERSION +\n")
			fmt.Fprintf(&sb, "          \" -- cue export -e sa_patch --out yaml\" +\n")
			fmt.Fprintf(&sb, "          \"%s\" +\n", tags)
			fmt.Fprintf(&sb, "          \" $(location //kernel/interface/k8s:irsa_patch.cue) > $@\",\n")
			fmt.Fprintf(&sb, ")\n\n")
		}

		// Generate domain patch if needed
		domainTags := fmt.Sprintf(" -t cluster_domain=%s", c.clusterDomain)
		if hasDomain {
			fmt.Fprintf(&sb, "genrule(\n")
			fmt.Fprintf(&sb, "    name = \"domain_patch_%s_gen\",\n", safeName)
			fmt.Fprintf(&sb, "    srcs = [\"//kernel/interface/k8s:domain_patch.cue\"],\n")
			fmt.Fprintf(&sb, "    outs = [\"domain_patch_%s.yaml\"],\n", safeName)
			fmt.Fprintf(&sb, "    cmd = \"mise x cue@\" + CUE_VERSION +\n")
			fmt.Fprintf(&sb, "          \" -- cue export -e oauth2_proxy_patch --out yaml\" +\n")
			fmt.Fprintf(&sb, "          \"%s\" +\n", domainTags)
			fmt.Fprintf(&sb, "          \" $(location //kernel/interface/k8s:domain_patch.cue) > $@\",\n")
			fmt.Fprintf(&sb, ")\n\n")
		}

		// Generate tailscale hostname patch if needed
		hasTailscale := overlay.tailscaleSvc != ""
		if hasTailscale {
			tsTags := fmt.Sprintf(" -t cluster_name=%s -t service_name=%s -t service_ns=%s",
				c.name, overlay.tailscaleSvc, overlay.tailscaleNS)
			fmt.Fprintf(&sb, "genrule(\n")
			fmt.Fprintf(&sb, "    name = \"tailscale_patch_%s_gen\",\n", safeName)
			fmt.Fprintf(&sb, "    srcs = [\"//kernel/interface/k8s:tailscale_patch.cue\"],\n")
			fmt.Fprintf(&sb, "    outs = [\"tailscale_patch_%s.yaml\"],\n", safeName)
			fmt.Fprintf(&sb, "    cmd = \"mise x cue@\" + CUE_VERSION +\n")
			fmt.Fprintf(&sb, "          \" -- cue export -e tailscale_patch --out yaml\" +\n")
			fmt.Fprintf(&sb, "          \"%s\" +\n", tsTags)
			fmt.Fprintf(&sb, "          \" $(location //kernel/interface/k8s:tailscale_patch.cue) > $@\",\n")
			fmt.Fprintf(&sb, ")\n\n")
		}

		// Run kustomize build: base YAML + patches -> per-cluster YAML
		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_kustomize_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    srcs = [\n")
		fmt.Fprintf(&sb, "        \"//%s/%s:app_kustomize_gen\",\n", verPkgPath, c.k8sVerDir)
		if hasIRSA {
			fmt.Fprintf(&sb, "        \":irsa_patch_%s_gen\",\n", safeName)
			fmt.Fprintf(&sb, "        \":irsa_sa_patch_%s_gen\",\n", safeName)
		}
		if hasDomain {
			fmt.Fprintf(&sb, "        \":domain_patch_%s_gen\",\n", safeName)
		}
		if hasTailscale {
			fmt.Fprintf(&sb, "        \":tailscale_patch_%s_gen\",\n", safeName)
		}
		if hasAppCueOverlay {
			fmt.Fprintf(&sb, "        %q,\n", appCueLabel)
		}
		fmt.Fprintf(&sb, "    ],\n")
		fmt.Fprintf(&sb, "    outs = [\"app_kustomize_%s.yaml\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"TMPWORK=$$(mktemp -d) &&\" +\n")
		fmt.Fprintf(&sb, "          \" cp $(location //%s/%s:app_kustomize_gen) $$TMPWORK/base.yaml &&\" +\n", verPkgPath, c.k8sVerDir)
		if hasIRSA {
			fmt.Fprintf(&sb, "          \" cp $(location :irsa_patch_%s_gen) $$TMPWORK/irsa-patch.yaml &&\" +\n", safeName)
			fmt.Fprintf(&sb, "          \" cp $(location :irsa_sa_patch_%s_gen) $$TMPWORK/sa-patch.yaml &&\" +\n", safeName)
		}
		if hasDomain {
			fmt.Fprintf(&sb, "          \" cp $(location :domain_patch_%s_gen) $$TMPWORK/domain-patch.yaml &&\" +\n", safeName)
		}
		if hasTailscale {
			fmt.Fprintf(&sb, "          \" cp $(location :tailscale_patch_%s_gen) $$TMPWORK/tailscale-patch.yaml &&\" +\n", safeName)
		}
		fmt.Fprintf(&sb, "          \" cat > $$TMPWORK/kustomization.yaml <<'KEOF'\\n\" +\n")
		fmt.Fprintf(&sb, "          \"apiVersion: kustomize.config.k8s.io/v1beta1\\n\" +\n")
		fmt.Fprintf(&sb, "          \"kind: Kustomization\\n\" +\n")
		fmt.Fprintf(&sb, "          \"resources:\\n\" +\n")
		fmt.Fprintf(&sb, "          \"  - base.yaml\\n\" +\n")
		if hasIRSA || hasDomain || hasTailscale {
			fmt.Fprintf(&sb, "          \"patches:\\n\" +\n")
		}
		if hasIRSA {
			fmt.Fprintf(&sb, "          \"  - path: irsa-patch.yaml\\n\" +\n")
			fmt.Fprintf(&sb, "          \"  - path: sa-patch.yaml\\n\" +\n")
		}
		if hasDomain {
			fmt.Fprintf(&sb, "          \"  - path: domain-patch.yaml\\n\" +\n")
		}
		if hasTailscale {
			fmt.Fprintf(&sb, "          \"  - path: tailscale-patch.yaml\\n\" +\n")
		}
		fmt.Fprintf(&sb, "          \"KEOF\\n\" +\n")
		fmt.Fprintf(&sb, "          \" mise x kustomize -- kustomize build $$TMPWORK > $@")
		if hasAppCueOverlay {
			// Append app.cue overlay objects to the kustomize output
			fmt.Fprintf(&sb, " &&\" +\n")
			fmt.Fprintf(&sb, "          \" echo '---' >> $@ &&\" +\n")
			overlayTags := fmt.Sprintf(" -t cluster_name=%s -t cluster_domain=%s -t dns_zone=%s", c.name, c.clusterDomain, c.dnsZone)
			fmt.Fprintf(&sb, "          \" mise x cue@\" + CUE_VERSION +\n")
			fmt.Fprintf(&sb, "          \" -- cue export -e '[ for _, kinds in objects for _, obj in kinds { obj } ]'\" +\n")
			fmt.Fprintf(&sb, "          \"%s\" +\n", overlayTags)
			fmt.Fprintf(&sb, "          \" --out json $(location %s)\" +\n", appCueLabel)
			fmt.Fprintf(&sb, "          \" | mise x yq@\" + YQ_VERSION +\n")
			fmt.Fprintf(&sb, "          \" -- yq -p json -o yaml '(.[] | splitDoc)' >> $@")
		}
		fmt.Fprintf(&sb, " &&\" +\n")
		fmt.Fprintf(&sb, "          \" rm -rf $$TMPWORK\",\n")
		fmt.Fprintf(&sb, ")\n\n")

		// Per-cluster digest
		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_digest_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    srcs = [\":app_kustomize_%s_gen\"],\n", safeName)
		fmt.Fprintf(&sb, "    outs = [\"helm_digest_%s.txt\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"sha256sum $(location :app_kustomize_%s_gen) | cut -d' ' -f1 > $@\",\n", safeName)
		fmt.Fprintf(&sb, ")\n\n")

		// Per-cluster helm chart
		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_chart_%s_yaml_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    outs = [\"helm_chart_%s.yaml\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"cat > $@ <<'CHARTEOF'\\n\" +\n")
		fmt.Fprintf(&sb, "          \"apiVersion: v2\\n\" +\n")
		fmt.Fprintf(&sb, "          \"name: %s\\n\" +\n", appName)
		fmt.Fprintf(&sb, "          \"version: %s\\n\" +\n", version)
		fmt.Fprintf(&sb, "          \"type: application\\n\" +\n")
		fmt.Fprintf(&sb, "          \"CHARTEOF\",\n")
		fmt.Fprintf(&sb, ")\n\n")

		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_templates_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    outs = [\"helm_templates_%s_all.yaml\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"printf '%%s' '{{- .Files.Get \\\"manifests.yaml\\\" }}' > $@\",\n")
		fmt.Fprintf(&sb, ")\n\n")

		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_package_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    srcs = [\n")
		fmt.Fprintf(&sb, "        \":app_kustomize_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "        \":app_helm_chart_%s_yaml_gen\",\n", safeName)
		fmt.Fprintf(&sb, "        \":app_helm_templates_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    ],\n")
		fmt.Fprintf(&sb, "    outs = [\"%s-%s-%s.tgz\"],\n", c.name, appName, version)
		fmt.Fprintf(&sb, "    cmd = \" TMPOUT=$$(mktemp -d) &&\" +\n")
		fmt.Fprintf(&sb, "          \" CHARTDIR=$$(mktemp -d)/%s &&\" +\n", appName)
		fmt.Fprintf(&sb, "          \" mkdir -p $$CHARTDIR/templates &&\" +\n")
		fmt.Fprintf(&sb, "          \" cp $(location :app_helm_chart_%s_yaml_gen) $$CHARTDIR/Chart.yaml &&\" +\n", safeName)
		fmt.Fprintf(&sb, "          \" mise x yq@\" + YQ_VERSION +\n")
		fmt.Fprintf(&sb, "          \" -- yq eval 'select(.kind != \\\"CustomResourceDefinition\\\")'\" +\n")
		fmt.Fprintf(&sb, "          \" $(location :app_kustomize_%s_gen) > $$CHARTDIR/manifests.yaml &&\" +\n", safeName)
		fmt.Fprintf(&sb, "          \" cp $(location :app_helm_templates_%s_gen) $$CHARTDIR/templates/all.yaml &&\" +\n", safeName)
		fmt.Fprintf(&sb, "          \" mise x helm@\" + HELM_VERSION +\n")
		fmt.Fprintf(&sb, "          \" -- helm package $$CHARTDIR -d $$TMPOUT &&\" +\n")
		fmt.Fprintf(&sb, "          \" mv $$TMPOUT/%s-%s.tgz $@ &&\" +\n", appName, version)
		fmt.Fprintf(&sb, "          \" rm -rf $$CHARTDIR $$TMPOUT\",\n")
		fmt.Fprintf(&sb, "    local = True,\n")
		fmt.Fprintf(&sb, ")\n\n")
	}
	return strings.TrimRight(sb.String(), "\n") + "\n"
}

// detectDeclaredTags scans gen-app.cue and app.cue under dirPath for
// @tag(...) declarations and returns the set of declared tag names.
// Also returns true if app.cue exists.
func detectDeclaredTags(workDir, dirPath string) (map[string]bool, bool) {
	declared := map[string]bool{}
	hasAppCue := false
	known := []string{
		"cluster_name", "account_id", "irsa_role_prefix",
		"oidc_provider_arn", "oidc_issuer_host",
		"cluster_domain", "dns_zone", "acme_endpoint",
	}
	for _, cueName := range []string{"gen-app.cue", "raw.cue", "app.cue"} {
		data, err := os.ReadFile(filepath.Join(workDir, dirPath, cueName))
		if err != nil {
			continue
		}
		if cueName == "app.cue" {
			hasAppCue = true
		}
		content := string(data)
		for _, tag := range known {
			if strings.Contains(content, "@tag("+tag+")") {
				declared[tag] = true
			}
		}
	}
	return declared, hasAppCue
}

// renderClusterGenrules produces Bazel genrule blocks for each cluster.
// Returns content with blank lines between blocks (buildifier convention)
// and a single trailing newline.
// Each cluster gets: cue export with declared cluster tags -> YAML -> helm chart.
// versions maps cluster name -> chart version; missing entries default to "0.0.1".
// declaredTags carries the @tag(...) names found in gen-app.cue/app.cue;
// only those tags are passed to cue export so apps with no cluster awareness
// still render through the per-cluster path (with three byte-identical YAMLs).
func renderClusterGenrules(appName string, versions map[string]string, clusters []clusterCtx, declaredTags map[string]bool, hasAppCue bool, cueSrc string) string {
	var sb strings.Builder
	for _, c := range clusters {
		safeName := strings.ReplaceAll(c.name, "-", "_")
		version := versions[c.name]
		if version == "" {
			version = "0.0.1"
		}
		var tagPairs []string
		add := func(name, value string) {
			// Pass the tag whenever the CUE declares it, even if the
			// cluster's value is empty. Empty is a legitimate value
			// (boot tenant has no IRSA, so rolePrefix=""); skipping it
			// would leave the @tag unbound and fail cue export on any
			// declaration without a CUE default.
			if declaredTags[name] {
				tagPairs = append(tagPairs, fmt.Sprintf("-t %s=%s", name, value))
			}
		}
		add("cluster_name", c.name)
		add("account_id", c.accountID)
		add("irsa_role_prefix", c.rolePrefix)
		add("oidc_provider_arn", c.oidcProviderARN)
		add("oidc_issuer_host", c.oidcIssuerHost)
		add("cluster_domain", c.clusterDomain)
		add("dns_zone", c.dnsZone)
		add("acme_endpoint", c.acmeEndpoint)
		var tags string
		if len(tagPairs) > 0 {
			tags = " " + strings.Join(tagPairs, " ")
		}

		// Build srcs and CUE file list. cueSrc is the raw app's
		// hand-written source cue file -- "raw.cue" after the filename-
		// honesty rename (AIDR-00146), or "gen-app.cue" for raw apps
		// whose gen-app.cue is generated (capsule-tenants) or not yet
		// renamed. Detected per-app by file existence in genApp.
		srcs := fmt.Sprintf("%q", cueSrc)
		cueSrcs := " --out json $(location " + cueSrc + ")"
		if hasAppCue {
			srcs += ", \"app.cue\""
			cueSrcs += " $(location app.cue)"
		}

		// Per-cluster YAML export
		fmt.Fprintf(&sb, "# Per-cluster rendering for %s\n", c.name)
		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_kustomize_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    srcs = [%s],\n", srcs)
		fmt.Fprintf(&sb, "    outs = [\"app_kustomize_%s.yaml\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"mise x cue@\" + CUE_VERSION +\n")
		fmt.Fprintf(&sb, "          \" -- cue export -e '[ for _, kinds in objects for _, obj in kinds { obj } ]'\" +\n")
		fmt.Fprintf(&sb, "          \"%s\" +\n", tags)
		fmt.Fprintf(&sb, "          \"%s\" +\n", cueSrcs)
		fmt.Fprintf(&sb, "          \" | mise x yq@\" + YQ_VERSION +\n")
		fmt.Fprintf(&sb, "          \" -- yq -p json -o yaml '(.[] | splitDoc)' > $@\",\n")
		fmt.Fprintf(&sb, ")\n\n")

		// Per-cluster digest
		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_digest_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    srcs = [\":app_kustomize_%s_gen\"],\n", safeName)
		fmt.Fprintf(&sb, "    outs = [\"helm_digest_%s.txt\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"sha256sum $(location :app_kustomize_%s_gen) | cut -d' ' -f1 > $@\",\n", safeName)
		fmt.Fprintf(&sb, ")\n\n")

		// Per-cluster helm chart
		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_chart_%s_yaml_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    outs = [\"helm_chart_%s.yaml\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"cat > $@ <<'CHARTEOF'\\n\" +\n")
		fmt.Fprintf(&sb, "          \"apiVersion: v2\\n\" +\n")
		fmt.Fprintf(&sb, "          \"name: %s\\n\" +\n", appName)
		fmt.Fprintf(&sb, "          \"version: %s\\n\" +\n", version)
		fmt.Fprintf(&sb, "          \"type: application\\n\" +\n")
		fmt.Fprintf(&sb, "          \"CHARTEOF\",\n")
		fmt.Fprintf(&sb, ")\n\n")

		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_templates_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    outs = [\"helm_templates_%s_all.yaml\"],\n", safeName)
		fmt.Fprintf(&sb, "    cmd = \"printf '%%s' '{{- .Files.Get \\\"manifests.yaml\\\" }}' > $@\",\n")
		fmt.Fprintf(&sb, ")\n\n")

		fmt.Fprintf(&sb, "genrule(\n")
		fmt.Fprintf(&sb, "    name = \"app_helm_package_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    srcs = [\n")
		fmt.Fprintf(&sb, "        \":app_kustomize_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "        \":app_helm_chart_%s_yaml_gen\",\n", safeName)
		fmt.Fprintf(&sb, "        \":app_helm_templates_%s_gen\",\n", safeName)
		fmt.Fprintf(&sb, "    ],\n")
		fmt.Fprintf(&sb, "    outs = [\"%s-%s-%s.tgz\"],\n", c.name, appName, version)
		fmt.Fprintf(&sb, "    cmd = \" TMPOUT=$$(mktemp -d) &&\" +\n")
		fmt.Fprintf(&sb, "          \" CHARTDIR=$$(mktemp -d)/%s &&\" +\n", appName)
		fmt.Fprintf(&sb, "          \" mkdir -p $$CHARTDIR/templates &&\" +\n")
		fmt.Fprintf(&sb, "          \" cp $(location :app_helm_chart_%s_yaml_gen) $$CHARTDIR/Chart.yaml &&\" +\n", safeName)
		fmt.Fprintf(&sb, "          \" mise x yq@\" + YQ_VERSION +\n")
		fmt.Fprintf(&sb, "          \" -- yq eval 'select(.kind != \\\"CustomResourceDefinition\\\")'\" +\n")
		fmt.Fprintf(&sb, "          \" $(location :app_kustomize_%s_gen) > $$CHARTDIR/manifests.yaml &&\" +\n", safeName)
		fmt.Fprintf(&sb, "          \" cp $(location :app_helm_templates_%s_gen) $$CHARTDIR/templates/all.yaml &&\" +\n", safeName)
		fmt.Fprintf(&sb, "          \" mise x helm@\" + HELM_VERSION +\n")
		fmt.Fprintf(&sb, "          \" -- helm package $$CHARTDIR -d $$TMPOUT &&\" +\n")
		fmt.Fprintf(&sb, "          \" mv $$TMPOUT/%s-%s.tgz $@ &&\" +\n", appName, version)
		fmt.Fprintf(&sb, "          \" rm -rf $$CHARTDIR $$TMPOUT\",\n")
		fmt.Fprintf(&sb, "    local = True,\n")
		fmt.Fprintf(&sb, ")\n\n")
	}
	return strings.TrimRight(sb.String(), "\n") + "\n"
}

func genCapsuleTenants(ctx *gen.Context, namespaces []string) error {
	ctDir := "tenant/library/app/capsule-tenants"
	os.MkdirAll(filepath.Join(ctx.WorkDir, ctDir), 0o755)

	var sb strings.Builder
	sb.WriteString("@experiment(aliasv2,explicitopen,shortcircuit,try)\n\npackage app\n\n")
	for _, ns := range namespaces {
		fmt.Fprintf(&sb, "objects: Namespace: \"%s\": {\n\tapiVersion: \"v1\"\n\tkind:       \"Namespace\"\n\tmetadata: name: \"%s\"\n}\n", ns, ns)
	}
	sb.WriteString("objects: ConfigMap: \"capsule-tenants\": {\n\tapiVersion: \"v1\"\n\tkind:       \"ConfigMap\"\n\tmetadata: {\n\t\tname:      \"capsule-tenants\"\n\t\tnamespace: \"capsule\"\n\t}\n\tdata: managed: \"true\"\n}\n")
	sb.WriteString("objects: Tenant: infra: {\n\tapiVersion: \"capsule.clastix.io/v1beta2\"\n\tkind:       \"Tenant\"\n\tmetadata: name: \"infra\"\n\tspec: {\n\t\tcordoned:        false\n\t\tpreventDeletion: false\n\t\towners: [{\n\t\t\tname: \"system:serviceaccount:argocd:argocd-application-controller\"\n\t\t\tkind: \"ServiceAccount\"\n\t\t\tclusterRoles: [\n\t\t\t\t\"admin\",\n\t\t\t\t\"capsule-namespace-deleter\",\n\t\t\t]\n\t\t}]\n\t}\n}\n")

	outPath := filepath.Join(ctx.WorkDir, ctDir, "gen-app.cue")
	if _, err := gen.WriteIfChanged(outPath, []byte(sb.String()), 0o644); err != nil {
		return fmt.Errorf("write gen-app.cue: %w", err)
	}
	if err := ctx.CueFmt(filepath.Join(ctDir, "gen-app.cue")); err != nil {
		return fmt.Errorf("cue fmt gen-app.cue: %w", err)
	}
	os.Chmod(outPath, 0o644)
	ctx.LogOK(fmt.Sprintf("generated %s/gen-app.cue", ctDir))
	return nil
}

// genKustomizationYAML generates kustomization.yaml for a kustomize app
// by combining catalog data (chart details) with app.cue (images, helm_values,
// kustomize_patches) and mirror data (image rewrites).
// outDir is where kustomization.yaml is written; for AIDR-00146 var-rendered
// apps it differs from dirPath (the source dir holding app.cue) -- the render
// lands in var/app/<name>/ while app.cue stays at tenant/.../app/<name>/.
func genKustomizationYAML(ctx *gen.Context, ad appData, dirPath, outDir, chartTgz string, mirrorBySource map[string]mirrorEntry, mirrorRegistry string) error {
	// Read app.cue to extract images and helm_values
	appCuePath := filepath.Join(ctx.WorkDir, dirPath, "app.cue")
	data, err := os.ReadFile(appCuePath)
	if err != nil {
		return fmt.Errorf("read app.cue: %w", err)
	}

	// Strip @experiment annotation and package line for standalone compilation
	lines := strings.Split(string(data), "\n")
	var cleaned []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "@experiment") || strings.HasPrefix(trimmed, "package ") {
			continue
		}
		cleaned = append(cleaned, line)
	}
	cueSrc := strings.Join(cleaned, "\n")

	freshCtx := cuecontext.New()
	appVal := freshCtx.CompileString(cueSrc)
	if appVal.Err() != nil {
		return fmt.Errorf("compile app.cue: %w", appVal.Err())
	}

	// Extract namespace (defaults to app name)
	namespace := ad.name
	nsVal := appVal.LookupPath(cue.ParsePath("namespace"))
	if nsVal.Exists() {
		if s, err := nsVal.String(); err == nil && s != "" {
			namespace = s
		}
	}

	// Extract images list
	var images []string
	imagesVal := appVal.LookupPath(cue.ParsePath("images"))
	if imagesVal.Exists() {
		iter, _ := imagesVal.List()
		for iter.Next() {
			s, _ := iter.Value().String()
			if s != "" {
				images = append(images, s)
			}
		}
	}

	// Extract helm_values as JSON (for YAML emission)
	var helmValuesJSON []byte
	hvVal := appVal.LookupPath(cue.ParsePath("helm_values"))
	if hvVal.Exists() {
		helmValuesJSON, err = hvVal.MarshalJSON()
		if err != nil {
			return fmt.Errorf("marshal helm_values: %w", err)
		}
	}

	// Extract kustomize_patches as JSON
	var patchesJSON []byte
	patchesVal := appVal.LookupPath(cue.ParsePath("kustomize_patches"))
	if patchesVal.Exists() {
		patchesJSON, err = patchesVal.MarshalJSON()
		if err != nil {
			return fmt.Errorf("marshal kustomize_patches: %w", err)
		}
	}

	// Extract helm_options
	var helmOptionsJSON []byte
	hoVal := appVal.LookupPath(cue.ParsePath("helm_options"))
	if hoVal.Exists() {
		helmOptionsJSON, err = hoVal.MarshalJSON()
		if err != nil {
			return fmt.Errorf("marshal helm_options: %w", err)
		}
	}

	// Build kustomization.yaml
	var buf strings.Builder
	buf.WriteString("# Generated by defn gen from app.cue + catalog. DO NOT EDIT.\n")
	buf.WriteString("apiVersion: kustomize.config.k8s.io/v1beta1\n")
	buf.WriteString("kind: Kustomization\n")
	buf.WriteString("helmGlobals:\n")
	buf.WriteString("  chartHome: charts\n")
	buf.WriteString("helmCharts:\n")
	buf.WriteString(fmt.Sprintf("  - name: %s\n", ad.chartName))
	buf.WriteString(fmt.Sprintf("    version: %s\n", ad.chartVersion))
	buf.WriteString(fmt.Sprintf("    releaseName: %s\n", ad.name))
	buf.WriteString(fmt.Sprintf("    namespace: %s\n", namespace))

	// Add helm_options (like includeCRDs)
	if len(helmOptionsJSON) > 0 {
		var opts map[string]interface{}
		json.Unmarshal(helmOptionsJSON, &opts)
		for k, v := range opts {
			switch val := v.(type) {
			case bool:
				buf.WriteString(fmt.Sprintf("    %s: %v\n", k, val))
			case string:
				buf.WriteString(fmt.Sprintf("    %s: %s\n", k, val))
			}
		}
	}

	// Add valuesInline if present
	if len(helmValuesJSON) > 0 {
		buf.WriteString("    valuesInline:\n")
		yamlLines := jsonToYAMLIndented(helmValuesJSON, 6)
		buf.WriteString(yamlLines)
	}

	// Add image rewrites
	if len(images) > 0 {
		buf.WriteString("images:\n")
		for _, img := range images {
			me, ok := mirrorBySource[img]
			if !ok {
				return fmt.Errorf("image %q not found in mirror catalog", img)
			}
			buf.WriteString(fmt.Sprintf("  - name: %s\n", img))
			buf.WriteString(fmt.Sprintf("    newName: %s/mirror/%s\n", mirrorRegistry, img))
			buf.WriteString(fmt.Sprintf("    newTag: %s\n", me.tag))
		}
	}

	// Add patches if present
	if len(patchesJSON) > 0 {
		var patches []interface{}
		json.Unmarshal(patchesJSON, &patches)
		buf.WriteString("patches:\n")
		for _, p := range patches {
			pm, ok := p.(map[string]interface{})
			if !ok {
				continue
			}
			// Emit target first
			if target, ok := pm["target"]; ok {
				buf.WriteString("  - target:\n")
				tm := target.(map[string]interface{})
				keys := make([]string, 0, len(tm))
				for k := range tm {
					keys = append(keys, k)
				}
				sort.Strings(keys)
				for _, k := range keys {
					buf.WriteString(fmt.Sprintf("      %s: %s\n", k, yamlScalar(tm[k])))
				}
			}
			// Emit patch as block scalar
			if patch, ok := pm["patch"]; ok {
				patchStr := patch.(string)
				buf.WriteString("    patch: |\n")
				for _, line := range strings.Split(patchStr, "\n") {
					if line == "" {
						continue
					}
					buf.WriteString(fmt.Sprintf("      %s\n", line))
				}
			}
		}
	}

	outPath := filepath.Join(ctx.WorkDir, outDir, "kustomization.yaml")
	os.MkdirAll(filepath.Dir(outPath), 0o755)
	_, err = gen.WriteIfChanged(outPath, []byte(buf.String()), 0o644)
	return err
}

// jsonToYAMLIndented converts JSON to indented YAML lines using yq-style output.
// This is a simple approach: marshal to JSON, then use Go to emit YAML-like output.
func jsonToYAMLIndented(jsonData []byte, indent int) string {
	var obj interface{}
	json.Unmarshal(jsonData, &obj)
	prefix := strings.Repeat(" ", indent)
	var buf strings.Builder
	writeYAML(&buf, obj, prefix, true)
	return buf.String()
}

func writeYAML(buf *strings.Builder, v interface{}, prefix string, first bool) {
	switch val := v.(type) {
	case map[string]interface{}:
		keys := make([]string, 0, len(val))
		for k := range val {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			child := val[k]
			switch child.(type) {
			case map[string]interface{}, []interface{}:
				fmt.Fprintf(buf, "%s%s:\n", prefix, k)
				writeYAML(buf, child, prefix+"  ", true)
			default:
				s := yamlScalar(child)
				if s == "block_scalar" {
					str := child.(string)
					fmt.Fprintf(buf, "%s%s: |-\n", prefix, k)
					for _, line := range strings.Split(str, "\n") {
						if line == "" {
							continue
						}
						fmt.Fprintf(buf, "%s  %s\n", prefix, line)
					}
				} else {
					fmt.Fprintf(buf, "%s%s: %s\n", prefix, k, s)
				}
			}
		}
	case []interface{}:
		for _, item := range val {
			switch item.(type) {
			case map[string]interface{}:
				fmt.Fprintf(buf, "%s- ", prefix)
				// Write first key inline after dash, rest indented
				m := item.(map[string]interface{})
				keys := make([]string, 0, len(m))
				for k := range m {
					keys = append(keys, k)
				}
				sort.Strings(keys)
				for i, k := range keys {
					child := m[k]
					if i == 0 {
						switch child.(type) {
						case map[string]interface{}, []interface{}:
							fmt.Fprintf(buf, "%s:\n", k)
							writeYAML(buf, child, prefix+"    ", true)
						default:
							fmt.Fprintf(buf, "%s: %s\n", k, yamlScalar(child))
						}
					} else {
						switch child.(type) {
						case map[string]interface{}, []interface{}:
							fmt.Fprintf(buf, "%s  %s:\n", prefix, k)
							writeYAML(buf, child, prefix+"    ", true)
						default:
							fmt.Fprintf(buf, "%s  %s: %s\n", prefix, k, yamlScalar(child))
						}
					}
				}
			default:
				fmt.Fprintf(buf, "%s- %s\n", prefix, yamlScalar(item))
			}
		}
	default:
		fmt.Fprintf(buf, "%s%s\n", prefix, yamlScalar(v))
	}
}

func yamlScalar(v interface{}) string {
	switch val := v.(type) {
	case string:
		// Multi-line strings use block scalar style
		if strings.Contains(val, "\n") {
			return "block_scalar"
		}
		// Quote if contains special chars or looks like a number
		if strings.ContainsAny(val, ":{}'#[],%&*!|>@`") || val == "" || val == "true" || val == "false" {
			return fmt.Sprintf("%q", val)
		}
		return val
	case float64:
		if val == float64(int64(val)) {
			return fmt.Sprintf("%d", int64(val))
		}
		return fmt.Sprintf("%g", val)
	case bool:
		return fmt.Sprintf("%v", val)
	case nil:
		return "null"
	default:
		return fmt.Sprintf("%v", val)
	}
}

// genAppBricks generates <catalog>/brick-app--*.cue for each app
// and kernel/catalog/brick_files.bzl. Per AIDR-00071, per-app brick
// files land in their owning tenant's catalog/ (tenant/<owner>/
// catalog/) when the app's path begins with tenant/<owner>/. Other
// apps fall back to kernel/catalog/. Mirrors stamp.go's
// brickCatalogDir() so restamp + app agree on placement.
func genAppBricks(ctx *gen.Context, appList []appData) error {
	kernelCatalogDir := filepath.Join(ctx.WorkDir, "kernel", "catalog")

	// 1. Generate brick-app--<name>.cue for each app, into the
	// owning tenant's catalog when the app's path is tenant-rooted.
	for _, ad := range appList {
		brickName := "brick-app--" + ad.name + ".cue"
		brickPath := filepath.Join(ctx.WorkDir, brickCatalogDir(ad.path), brickName)
		slug := gen.DefaultBrickSlug(ad.path)
		content := fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	%q: {
		path:       %q
		slug:       %q
		kind:       "component"
		desc:       %q
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
`, ad.path, ad.path, slug, ad.desc)
		if _, err := gen.WriteIfChanged(brickPath, []byte(content), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", brickName, err)
		}
	}

	// 2. Generate brick_files.bzl by scanning kernel/catalog/ only
	// (tenant catalogs maintain their own coverage via tagged_package
	// in tenant/<t>/catalog/BUILD.bazel).
	entries, err := os.ReadDir(kernelCatalogDir)
	if err != nil {
		return fmt.Errorf("read catalog dir: %w", err)
	}
	var brickFiles []string
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), "brick-") && strings.HasSuffix(e.Name(), ".cue") {
			brickFiles = append(brickFiles, e.Name())
		}
	}
	sort.Strings(brickFiles)
	var bzlBuf strings.Builder
	bzlBuf.WriteString("# Generated list of per-brick CUE files in catalog/.\n")
	bzlBuf.WriteString("# Updated by stamp and gen.\n\n")
	bzlBuf.WriteString("BRICK_FILES = [\n")
	for _, f := range brickFiles {
		fmt.Fprintf(&bzlBuf, "    %q,\n", f)
	}
	bzlBuf.WriteString("]\n")
	bzlPath := filepath.Join(kernelCatalogDir, "brick_files.bzl")
	if _, err := gen.WriteIfChanged(bzlPath, []byte(bzlBuf.String()), 0o644); err != nil {
		return fmt.Errorf("write brick_files.bzl: %w", err)
	}

	return nil
}

// brickCatalogDir mirrors stamp.brickCatalogDir: tenant-rooted
// brick paths go to tenant/<owner>/catalog/, everything else to
// kernel/catalog/. Inlined here to keep the gen/app package free of
// a stamp-package dep cycle. See AIDR-00071.
func brickCatalogDir(path string) string {
	parts := strings.Split(path, "/")
	if len(parts) >= 2 && parts[0] == "tenant" {
		return filepath.Join("tenant", parts[1], "catalog")
	}
	return filepath.Join("kernel", "catalog")
}
