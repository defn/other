@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: var/ -- hand-written files in the top-level
// volatile var/ dir (AIDR-00145 D5.1).
//
// var/ holds workspace-derived generator outputs (gen-*.cue, the
// lattice payload) which are claimed by their generators' contracts.
// The only hand-written files are the BUILD.bazel scaffolding, which
// is content-independent (glob + tagged_package) so it stays stable as
// var/ content changes. One of multiple manual-files-*.cue shards per
// AIDR-00083; see contracts-schema.cue for the _manualFileShards
// aggregation pattern.

package contracts

_manualFileShards: var: [
	"kernel/spec/manual-files-var.cue",
	"var/BUILD.bazel",
	"var/lattice/BUILD.bazel",
]
