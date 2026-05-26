@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: seed generator.
//
// Traceability:
//   Go source:      go/lib/gen/seed/seed.go
//   Reads:          catalog/catalog.cue (patches in place)
//
// Why these files exist: seed runs in pre-phase 0 before the main
// parallel phase A. It ensures catalog/catalog.cue has a baseline
// state (patching version fields if the catalog is new or reset)
// and seeds catalog/gen-chart-digests.cue with placeholder digests
// so later generators that consume it have something to read.
//
// Multi-writer alert: seed and buildsync BOTH claim
// catalog/gen-chart-digests.cue. This is intentional -- seed
// writes the initial placeholder entries (pre-phase 0) and
// buildsync overwrites them with real build digests after Bazel
// runs (post-phase A). See spec/known-shared.cue for the
// documented shared-writer entry.
//
// catalog/catalog.cue is patched by seed but NOT rewritten from
// scratch -- its bulk content is hand-edited (platforms, apps,
// environments, k3d_clusters, etc.). The "patched" claim here is
// over the entire file for contract purposes, with the patch
// semantics captured in spec/known-shared.cue.
//
// See AIDR-00062.

package contracts

generators: seed: {
	generator: "seed"
	source:    "tenant/library/go/lib/gen/seed"
	reason:    "pre-phase 0 seeder: writes initial catalog/gen-chart-digests.cue placeholders so phase A generators see a consistent starting state, and appends auto-seeded chart_versions entries to per-tenant overlay files when platform apps lack entries"
	read_from: {
		paths: ["kernel/catalog/catalog.cue"]
	}
	related_aidr: [62, 72]
	paths: [
		"var/gen-chart-digests.cue",
		// kernel/spec/tenant-deps.bzl is emitted by seed in step 3
		// (AIDR-00138 D5.3) so kernel/spec/BUILD.bazel can load
		// per-tenant filegroup labels rather than hardcoding tenants.
		"kernel/spec/tenant-deps.bzl",
		// Per-tenant chart_versions overlay: one file per tenant that
		// has a catalog/ dir AND that catalog already declares a
		// chart_versions.cue file. seed only appends to existing files
		// (per AIDR-00072); it does not create one for tenants without
		// clusters (e.g. library, which is upstream-only and has no
		// per-cluster version data).
		for tName, t in tree.dirs.m.dirs.tenant.dirs
		if t.dirs != _|_
		if t.dirs.catalog != _|_
		if t.dirs.catalog.files != _|_
		if t.dirs.catalog.files["chart_versions.cue"] != _|_ {"tenant/\(tName)/catalog/chart_versions.cue"},
	]
}
