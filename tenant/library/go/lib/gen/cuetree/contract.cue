@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: cuetree generator.
//
// Traceability:
//   Go source:      go/lib/gen/cuetree/cuetree.go
//   Reads:          git ls-files
//
// Why this file exists: cuetree walks the git index and emits a
// single CUE file describing the repo's tree shape at
// manifest/gen-manifest.cue. The manifest schema
// (manifest/manifest.cue) unifies against this to enforce
// "every committed file has a place in the typed directory tree."
//
// Runs in Phase B (sequential), after all Phase A generators so its
// output reflects their writes.
//
// See AIDR-00062.

package contracts

generators: cuetree: {
	generator: "cuetree"
	source:    "tenant/library/go/lib/gen/cuetree"
	reason:    "emits manifest/gen-manifest.cue from git ls-files so the typed tree schema (manifest/manifest.cue) can validate every tracked file's location and mode"
	read_from: {
		path_globs: ["**"]
	}
	related_aidr: [62]
	paths: [
		"var/gen-manifest.cue",
	]
}
