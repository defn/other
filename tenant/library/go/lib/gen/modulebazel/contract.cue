@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: modulebazel generator.
//
// Traceability:
//   Go source:   go/lib/gen/modulebazel/modulebazel.go
//   Reads:       schema.versions (per-tool entries)
//
// Why these files exist: Bazel's MODULE.bazel and .bazelversion can't
// be authored purely from CUE because Bazel parses them as Starlark.
// modulebazel patches version strings in place with regex
// substitution, keeping the hand-written Bazel module structure
// intact while guaranteeing the pinned versions match the canonical
// catalog. .bazelversion is rewritten from scratch.
//
// Treat as "generated" even though MODULE.bazel retains hand-written
// structure: ownership is unambiguous for the version-string
// portions, and contracts claim the *file*, not line ranges.
//
// See AIDR-00062.

package contracts

generators: modulebazel: {
	generator: "modulebazel"
	source:    "tenant/library/go/lib/gen/modulebazel"
	reason:    "patches version strings in MODULE.bazel + writes .bazelversion from schema.versions so Bazel pins stay synced with the canonical catalog"
	read_from: {
		schema: ["versions"]
	}
	related_aidr: [62]
	paths: [
		".bazelversion",
		"MODULE.bazel",
	]
}
