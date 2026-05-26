@experiment(aliasv2,explicitopen,shortcircuit,try)

// Known-shared: allow-list for files claimed by more than one
// generator.
//
// The contracts_vet harness detects multi-writer paths automatically
// (a path appears in two generators' `paths` lists). Each such path
// MUST appear here with:
//   - writers: the set of generator IDs that claim it
//   - reason: why multi-writer is the current shape
//   - consolidate: the plan to collapse writers (or "keep as-is" with
//                  a justification)
//
// Intent: the multi-writer list is the maintenance backlog for
// "should this file have one owner?" -- new entries are friction,
// and friction is the point.
//
// Day one in the go/cmd/ scope has zero genuine collisions. Every
// file in go/cmd/ is claimed by exactly one of gocmd / gocmdcue /
// gocmdparent, because the three generators partition by catalog
// `implements` field + `parent` field. This file is empty for now
// but the mechanism is wired so the first real collision -- when it
// lands -- hits the vet hard.
//
// See AIDR-00062.

package contracts

knownShared: {
	// First real multi-writer case (phase 10 expansion): seed and
	// buildsync both claim var/gen-chart-digests.cue (moved out of
	// kernel/catalog/ to the top-level volatile var/ dir per
	// AIDR-00145 D5.1; re-projected into package catalog via the gen
	// var overlay).
	//
	// seed writes it in pre-phase 0 with per-app per-cluster
	// placeholder entries so downstream CUE evaluation has something
	// to look up. buildsync rewrites it in Phase C from the actual
	// Bazel-built helm chart SHA256s (one digest per app per cluster).
	//
	// The two writes happen at different pipeline phases, so there's
	// no race -- seed always runs first. Consolidation would require
	// moving the placeholder logic into buildsync, which is feasible
	// but would couple pre-phase seeding to post-build sync.
	"var/gen-chart-digests.cue": {
		path: "var/gen-chart-digests.cue"
		writers: ["seed", "buildsync"]
		reason:      "seed writes placeholder digests per app/cluster in pre-phase 0 so downstream CUE sees a consistent shape; buildsync replaces the placeholders with real Bazel chart SHAs in phase C"
		consolidate: "future: merge placeholder generation into buildsync and drop seedChartDigests. deferred because the two-phase ordering is load-bearing for downstream generators that read chart_versions."
	}
}
