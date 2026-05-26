@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: buildsync generator.
//
// Traceability:
//   Go source:   go/lib/gen/buildsync/buildsync.go
//   Reads:       bazel-bin/<path>/*_gen.{yaml,toml,cue,json,mod,work}
//   Reads catalogs for sync-set enumeration:
//                catalog.k3d_clusters, catalog.apps,
//                catalog.environments, catalog.k8s_platforms,
//                schema.versions (for k8s version dirs),
//                catalog.chart_versions
//
// Why these files exist: buildsync is the "sync generated files from
// Bazel output back into the workspace" step. Bazel genrules render
// a lot of files (package.json, go.mod, hello/hello.yaml, per-k3d
// k3d.yaml/mise.toml, per-app gen-app.cue variants), but Bazel writes
// them under bazel-bin/. Developers and other generators need the
// files at their canonical workspace paths. buildsync does the copy.
//
// The important design property: files claimed here are NOT written
// by hand and should NOT be listed in spec/manual-files.cue. Before
// AIDR-00062 day-1, go.mod/go.work/package.json were in the manual
// list by mistake -- they're synced from Bazel output, not human-
// edited. Phase 2 moves them here.
//
// Non-k3d apps outside go/cmd/ (riverqueue, tailscale-dns-policy,
// terraform-operator-crds, arc-runners, etc.) have parent gen-app.cue
// files but no per-version subdir, so they appear only in _appParents.
// The versioned ones appear in BOTH lists because buildsync writes
// the parent by copying from a selected version dir (buildsync.go:82).
//
// See AIDR-00062.

package contracts

import "list"

// Bind catalog.k3d_clusters so the contract can iterate it
// directly (parallel to k3d/contract.cue's binding). CUE forbids
// referencing undeclared fields, so the placeholder is required.
k3d_clusters: _

_buildsync: {
	// Parent gen-app.cue files synced by buildsync. Only kustomize
	// apps are included -- buildsync.appEntries filters on
	// `kind == "kustomize"` (see buildsync.go:120). The 28 names
	// here match versionedApps below, because buildsync synthesizes
	// the parent gen-app.cue from the selected versioned subdir
	// (see buildsync.go:82).
	//
	// Raw apps (aws-acc-*, capsule-tenants, *-crds, letsencrypt-
	// issuer, riverqueue, tailscale-dns-policy, aws-secret-store,
	// aws-irsa-roles, arc-runners, external-dns-cloudflare) are
	// NOT synced here. Their gen-app.cue comes from:
	//   - awstofu: aws-acc-jianghu-ops (see awstofu contract)
	//   - app.genCapsuleTenants: capsule-tenants (TODO: contract)
	//   - operatorcrds: terraform-operator-crds (see oct contract)
	//   - hand-written: the rest (listed in manual-files.cue when
	//     their subtree is scoped)
	appParents: [
		"ack-iam",
		"arc",
		"argocd",
		"argo-rollouts",
		"buildbuddy",
		"capsule",
		"cert-manager",
		"cloudnative-pg",
		"coder",
		"dex",
		"external-dns",
		"external-secrets",
		"goldilocks",
		"k3k",
		"karpenter",
		"keda",
		"kyverno",
		"linkerd-control-plane",
		"linkerd-crds",
		"metrics-server",
		"oauth2-proxy",
		"redis-operator",
		"reloader",
		"tailscale-operator",
		"temporal",
		"topolvm",
		"traefik",
		"trust-manager",
		"vpa",
	]

	// Apps that have per-k8s-version subdirs. Each produces files at
	// app/<name>/k8s-1-{33,34,35}/gen-app.cue.
	versionedApps: [
		"ack-iam",
		"arc",
		"argocd",
		"argo-rollouts",
		"buildbuddy",
		"capsule",
		"cert-manager",
		"cloudnative-pg",
		"coder",
		"dex",
		"external-dns",
		"external-secrets",
		"goldilocks",
		"k3k",
		"karpenter",
		"keda",
		"kyverno",
		"linkerd-control-plane",
		"linkerd-crds",
		"metrics-server",
		"oauth2-proxy",
		"redis-operator",
		"reloader",
		"tailscale-operator",
		"temporal",
		"topolvm",
		"traefik",
		"trust-manager",
		"vpa",
	]

	// k8s API version dirs. Matches schema.k8s_versions keys.
	k8sVersions: [
		"k8s-a",
		"k8s-b",
		"k8s-c",
	]

	// k3d cluster workspace paths derived from catalog.k3d_clusters
	// at lattice-load time. Adding/removing a cluster (or moving from
	// defn -> boot etc.) does not require editing this file. Per
	// AIDR-00138 D5.3 -- the kernel substrate has no hardcoded tenant
	// paths; fork-portable.
	k3dClusters: [
		for _, c in k3d_clusters {c.path},
	]

	// Fixed outputs synced from bazel-bin to workspace.
	// (root/.aws/config is generated directly by awsconfig, not synced
	// here -- see buildsync.go's syncOp list.)
	fixedPaths: [
		"package.json",
		"go.mod",
		"go.work",
		"cue.mod/module.cue",
		"var/gen-chart-digests.cue",
	]

	// AIDR-00146: every kustomize app var-renders, so its gen-app.cue (parent +
	// versioned) is synced to var/app/<name>/. appParents/versionedApps are
	// exactly the kustomize apps.
	_parentAppPaths: [
		for n in appParents {"var/app/\(n)/gen-app.cue"},
	]

	_versionedAppPaths: [
		for n in versionedApps
		for v in k8sVersions {"var/app/\(n)/\(v)/gen-app.cue"},
	]

	// Per-k3d-cluster files: buildsync writes 4 per cluster (k3d.yaml,
	// mise.toml, .kube/.gitignore, and bootstrap.yaml when the env
	// has argocd -- all three day-one clusters do).
	_k3dPaths: [
		for p in k3dClusters {"\(p)/k3d.yaml"},
		for p in k3dClusters {"\(p)/mise.toml"},
		for p in k3dClusters {"\(p)/.kube/.gitignore"},
		for p in k3dClusters {"\(p)/bootstrap.yaml"},
	]

	allPaths: list.Concat([
		fixedPaths,
		_parentAppPaths,
		_versionedAppPaths,
		_k3dPaths,
	])
}

generators: buildsync: {
	generator: "buildsync"
	source:    "tenant/library/go/lib/gen/buildsync"
	reason:    "copies generator outputs from bazel-bin to their canonical workspace paths (per-app gen-app.cue, per-k3d k3d.yaml/mise.toml, go.mod/work, package.json, etc.) so developers and downstream generators see committed files"
	read_from: {
		path_globs: ["bazel-bin/**/*"]
		catalog: [
			"k3d_clusters",
			"apps",
			"environments",
			"k8s_platforms",
			"chart_versions",
		]
		schema: ["versions"]
	}
	related_aidr: [62]
	paths: _buildsync.allPaths
}
