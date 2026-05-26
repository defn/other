@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: app generator.
//
// Traceability:
//   Go source:      go/lib/gen/app/app.go
//   Reads catalogs: catalog.apps, catalog.versions, gen-crds-apps.cue
//   Template:       interface/app/templates.cue
//
// Why these files exist: the `app` generator is the heart of the
// Kubernetes app catalog. For every entry in catalog.apps (plus the
// -crds companions from catalog.gen-crds-apps.cue), it writes:
//
// 1. app/<name>/BUILD.bazel -- Bazel wiring per app.
// 2. app/<name>/kustomization.yaml -- for kustomize-kind apps only,
//    built from app.cue helm_values + mirror registry rewrites.
// 3. app/<name>/k8s-1-{33,34,35}/BUILD.bazel -- per k8s API version
//    for kustomize-kind apps (84 total = 28 apps * 3 versions).
// 4. app/capsule-tenants/gen-app.cue -- written by genCapsuleTenants
//    (line 742). This is the only gen-app.cue claimed by the app
//    generator itself; all other gen-app.cue files come from
//    buildsync (kustomize), awstofu (aws-acc-*), operatorcrds
//    (terraform-operator-crds), or are hand-written (raw apps
//    without a generator). See the per-file notes below.
// 5. catalog/brick-app--<name>.cue -- one per app, auto-generated
//    catalog entry with stamp_type: "gen".
// 6. catalog/brick_files.bzl -- generated list of every brick-*.cue
//    for Bazel file discovery.
//
// Raw apps with hand-written gen-app.cue (grandfathered in
// spec/manual-files.cue): ack-iam-crds, arc-crds, arc-runners,
// argocd-crds, argo-rollouts-crds, aws-irsa-roles, aws-secret-store,
// cert-manager-crds, cloudnative-pg-crds, external-dns-cloudflare,
// external-dns-crds, external-secrets-crds, keda-crds, kyverno-crds,
// letsencrypt-issuer, linkerd-crds, redis-operator-crds, riverqueue,
// tailscale-dns-policy, tailscale-operator-crds, topolvm-crds,
// traefik-crds, trust-manager-crds.
//
// The kustomize vs raw split mirrors catalog.apps[*].kind. Raw apps
// get only a BUILD.bazel from this generator; kustomize apps also
// get kustomization.yaml and versioned k8s-1-* subdirs.
//
// See AIDR-00062.

package contracts

import (
	"list"
	"strings"
)

// Bind catalog.apps from the lattice JSON. Every app (kustomize and
// raw, including -crds companions) is discoverable by iteration.
// Default optional fields so comprehensions can filter on them.
apps: [string]: {
	name: string
	kind: string | *""
	path: string | *""
	...
}

_app: {
	// k8s API versions (matches schema.k8s_versions + misetoml
	// versioning in schema/versions.cue). Kept static because this is
	// the generator's *own* fixed render matrix, not a catalog roster.
	k8sVersions: [
		"k8s-a",
		"k8s-b",
		"k8s-c",
	]

	// AIDR-00146: every kustomize app var-renders -- its generated render
	// (render-side BUILD.bazel, kustomization.yaml, versioned k8s-* BUILD.bazel)
	// is evicted to var/app/<name>/. Only the source-side BUILD.bazel stays at
	// a.path. Raw apps keep a single source-dir BUILD.bazel.
	_perAppBuild: [
		for _, a in apps {"\(a.path)/BUILD.bazel"},
	]

	// Render-side BUILD.bazel for each kustomize app.
	_varRenderBuild: [
		for n, a in apps if a.kind == "kustomize" {"var/app/\(n)/BUILD.bazel"},
	]

	_kustomizationYaml: [
		for n, a in apps if a.kind == "kustomize" {"var/app/\(n)/kustomization.yaml"},
	]

	_versionedBuild: [
		for n, a in apps if a.kind == "kustomize"
		for v in k8sVersions {"var/app/\(n)/\(v)/BUILD.bazel"},
	]

	// Catalog brick files written by app's genAppBricks. Per
	// AIDR-00071, a per-app brick lands in its owning tenant's
	// catalog/ when the app's path is rooted at tenant/<owner>/;
	// otherwise it falls back to kernel/catalog/. Mirrors the rule
	// in stamp.go's brickCatalogDir() and app.go's genAppBricks.
	_brickFiles: [
		for n, a in apps
		let parts = strings.Split(a.path, "/")
		if len(parts) >= 2
		if parts[0] == "tenant" {"tenant/\(parts[1])/catalog/brick-app--\(n).cue"},
		for n, a in apps
		let parts = strings.Split(a.path, "/")
		if !(len(parts) >= 2 && parts[0] == "tenant") {"kernel/catalog/brick-app--\(n).cue"},
	]

	_catalogGlue: [
		"kernel/catalog/brick_files.bzl",
	]

	// capsule-tenants is the only gen-app.cue the app generator
	// writes directly, via genCapsuleTenants (app.go:742).
	_capsuleTenantsGenApp: [
		"tenant/library/app/capsule-tenants/gen-app.cue",
	]

	allPaths: list.Concat([
		_perAppBuild,
		_varRenderBuild,
		_kustomizationYaml,
		_versionedBuild,
		_brickFiles,
		_catalogGlue,
		_capsuleTenantsGenApp,
	])
}

generators: app: {
	generator: "app"
	source:    "tenant/library/go/lib/gen/app"
	reason:    "stamps the Kubernetes app catalog: per-app BUILD.bazel, per-kustomize-app kustomization.yaml + versioned k8s-1-XX BUILD.bazel, per-app catalog/brick-app--*.cue entries, and the capsule-tenants gen-app.cue (the only gen-app.cue it writes directly)"
	read_from: {
		catalog: [
			"apps",
			"versions",
		]
		paths: [
			"kernel/interface/app/templates.cue",
			"tenant/library/catalog/gen-crds-apps.cue",
		]
	}
	related_aidr: [61, 62]
	paths: list.Concat([
		_app.allPaths,
		// In-brick hand-authored files (app.cue, *.tgz, values*.yaml,
		// instance.cue, and gen-app.cue for raw apps); map populated by
		// the app generator in the generated inputs block below.
		[for b, fs in _app_inputs
			for f in fs {"\(b)/\(f)"}],
	])
}

// === BEGIN GENERATED: _app_inputs ===
// Per-brick in-brick file roster emitted by app.
// Rewritten by `mise run gen`. Do not hand-edit this section.
// Pattern B (AIDR-00093 fold): see contracts-schema.cue header.

_app_inputs: [string]: [...string]

_app_inputs: {
	"tenant/library/app/ack-iam": ["app.cue", "iam-chart-1.6.4.tgz"]
	"tenant/library/app/ack-iam-crds": ["raw.cue"]
	"tenant/library/app/arc": ["app.cue", "gha-runner-scale-set-controller-0.14.2.tgz"]
	"tenant/library/app/arc-crds": ["raw.cue"]
	"tenant/library/app/arc-runners": ["app.cue", "raw.cue"]
	"tenant/library/app/argo-rollouts": ["app.cue", "argo-rollouts-2.40.9.tgz"]
	"tenant/library/app/argo-rollouts-crds": ["raw.cue"]
	"tenant/library/app/argocd": ["app.cue", "argo-cd-9.5.15.tgz"]
	"tenant/library/app/argocd-crds": ["raw.cue"]
	"tenant/library/app/buildbuddy": ["app.cue", "buildbuddy-0.0.409.tgz"]
	"tenant/library/app/capsule": ["app.cue", "capsule-0.12.4.tgz"]
	"tenant/library/app/capsule-tenants": ["gen-app.cue"]
	"tenant/library/app/cert-manager": ["app.cue", "cert-manager-v1.20.2.tgz"]
	"tenant/library/app/cert-manager-crds": ["raw.cue"]
	"tenant/library/app/cloudnative-pg": ["app.cue", "cloudnative-pg-0.28.2.tgz"]
	"tenant/library/app/cloudnative-pg-crds": ["raw.cue"]
	"tenant/library/app/coder": ["app.cue", "coder_helm_2.33.6.tgz", "instance.cue"]
	"tenant/library/app/dex": ["app.cue", "dex-0.24.0.tgz"]
	"tenant/library/app/external-dns": ["app.cue", "external-dns-1.21.1.tgz"]
	"tenant/library/app/external-dns-cloudflare": ["app.cue", "raw.cue"]
	"tenant/library/app/external-dns-crds": ["raw.cue"]
	"tenant/library/app/external-secrets": ["app.cue", "external-secrets-2.5.0.tgz"]
	"tenant/library/app/external-secrets-crds": ["raw.cue"]
	"tenant/library/app/goldilocks": ["app.cue", "goldilocks-10.3.0.tgz"]
	"tenant/library/app/k3k": ["app.cue", "k3k-1.1.0.tgz"]
	"tenant/library/app/k3k-crds": ["raw.cue"]
	"tenant/library/app/karpenter": ["app.cue", "karpenter-1.12.1.tgz"]
	"tenant/library/app/keda": ["app.cue", "keda-2.19.0.tgz"]
	"tenant/library/app/keda-crds": ["raw.cue"]
	"tenant/library/app/kyverno": ["app.cue", "kyverno-3.8.1.tgz"]
	"tenant/library/app/kyverno-crds": ["raw.cue"]
	"tenant/library/app/letsencrypt-issuer": ["raw.cue"]
	"tenant/library/app/linkerd-control-plane": ["app.cue", "linkerd-control-plane-1.16.11.tgz"]
	"tenant/library/app/linkerd-crds": ["app.cue", "linkerd-crds-1.8.0.tgz"]
	"tenant/library/app/metrics-server": ["app.cue", "metrics-server-3.13.0.tgz"]
	"tenant/library/app/oauth2-proxy": ["app.cue", "oauth2-proxy-10.6.0.tgz"]
	"tenant/library/app/redis-operator": ["app.cue", "redis-operator-0.24.0.tgz"]
	"tenant/library/app/redis-operator-crds": ["raw.cue"]
	"tenant/library/app/reloader": ["app.cue", "reloader-2.2.12.tgz"]
	"tenant/library/app/riverqueue": ["app.cue", "raw.cue"]
	"tenant/library/app/tailscale-dns-policy": ["app.cue", "raw.cue"]
	"tenant/library/app/tailscale-operator": ["app.cue", "tailscale-operator-1.98.3-1779463621-a7413eb0ce91581ff66fc71a17da0cf19a1a822ed7a84fb4b52786ceb17065a0.tgz"]
	"tenant/library/app/tailscale-operator-crds": ["raw.cue"]
	"tenant/library/app/temporal": ["app.cue", "temporal-1.2.0.tgz"]
	"tenant/library/app/topolvm": ["app.cue", "topolvm-16.1.0.tgz"]
	"tenant/library/app/topolvm-crds": ["raw.cue"]
	"tenant/library/app/traefik": ["app.cue", "traefik-40.2.0.tgz"]
	"tenant/library/app/traefik-crds": ["raw.cue"]
	"tenant/library/app/trust-manager": ["app.cue", "trust-manager-v0.22.1.tgz"]
	"tenant/library/app/trust-manager-crds": ["raw.cue"]
	"tenant/library/app/vpa": ["app.cue", "vpa-4.11.0.tgz"]
}

// === END GENERATED: _app_inputs ===
