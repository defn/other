@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: k3d generator.
//
// Traceability:
//   Go source:      go/lib/gen/k3d/k3d.go
//   Reads catalogs: catalog.k3d_clusters, catalog.environments,
//                   catalog.k8s_platforms, catalog.chart_versions,
//                   catalog.apps, catalog.aws_state
//   Template:       interface/k3d/templates.cue,
//                   interface/aws/templates.cue (for IRSA main.tf)
//
// Why these files exist: each k3d cluster (a, b, c) has its own
// brick directory with BUILD.bazel wiring, cluster.cue config,
// .gitignore, main.tf (IRSA terraform), and apps.yaml (ArgoCD
// applications list). The k3d generator stamps the first three from
// interface/k3d/templates.cue, the main.tf from interface/aws/
// templates.cue, and the apps.yaml from a computed merge of
// platform + overlay apps via genAppsYAML.
//
// NOT claimed by this contract (claimed by buildsync):
//   - k3d/<cluster>/k3d.yaml       (rendered by Bazel genrule)
//   - k3d/<cluster>/mise.toml      (rendered by Bazel genrule)
//   - k3d/<cluster>/.kube/.gitignore (rendered by Bazel genrule)
//   - k3d/<cluster>/bootstrap.yaml (rendered by Bazel + kustomize)
//
// NOT claimed by this contract (tofu-stamped at create time, gitignored):
//   - k3d/<cluster>/irsa.cue       (written by `tofu apply` against
//                                   main.tf; supplies oidc_issuer_url
//                                   + oidc_bucket_name to gen-app
//                                   inputs for the next gen pass)
//
// This is the first real split-ownership in the contract graph:
// k3d writes the "definitional" files (what the cluster IS) and
// buildsync writes the "built from Bazel" files (what Bazel renders
// per-cluster for mise/kubectl use). No multi-writer because the
// paths are disjoint.
//
// k3d/BUILD.bazel at the top level is hand-written -- it's a simple
// tagged_package directive that doesn't need generation. It lives in
// spec/manual-files.cue.
//
// See AIDR-00062 (generator contracts) and AIDR-00066
// (auto-claim taxonomy).
//
// This contract is a canonical Pattern A (catalog comprehension)
// exemplar. For the other two claim patterns and when to use each,
// see the "How to declare `paths`" header in spec/contracts-schema.cue.

package contracts

// Bind the catalog.k3d_clusters field from the lattice JSON so the
// contract can iterate it directly (parallel to `tree: _` in
// spec/contracts-schema.cue). CUE forbids referencing undeclared
// fields, so the placeholder is required.
k3d_clusters: _

_k3d: {
	// Filenames written per cluster by k3d.Run. The cluster list itself
	// is read directly from catalog.k3d_clusters in the lattice data
	// that cue vet ingests -- no hand-maintained mirror of the cluster
	// roster is needed. Adding a new cluster to catalog.k3d_clusters
	// is sufficient; the claim list picks it up automatically on the
	// next `mise run hatch`.
	filenames: [
		"BUILD.bazel",
		"cluster.cue",
		".gitignore",
		"main.tf",
		"apps.yaml",
	]
}

generators: k3d: {
	generator: "k3d"
	source:    "tenant/library/go/lib/gen/k3d"
	reason:    "stamps self-contained k3d cluster brick dirs (BUILD.bazel + cluster.cue + .gitignore + IRSA main.tf + computed apps.yaml) from catalog.k3d_clusters so each local cluster is reproducible from CUE config"
	read_from: {
		catalog: [
			"k3d_clusters",
			"environments",
			"k8s_platforms",
			"chart_versions",
			"apps",
			"aws_state",
		]
		paths: [
			"kernel/interface/k3d/templates.cue",
			"kernel/interface/aws/templates.cue",
		]
	}
	related_aidr: [62]
	// Iterate catalog.k3d_clusters from the lattice directly. Each
	// entry's `path` is the brick dir; cross it with the generator's
	// fixed per-cluster filename set to produce the claim list.
	paths: [
		for _, c in k3d_clusters
		for f in _k3d.filenames {"\(c.path)/\(f)"},
	]
}
