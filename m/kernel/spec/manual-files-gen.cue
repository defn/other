@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: gen/ -- gen task BUILD files.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: gen: [
	"kernel/spec/manual-files-gen.cue",
	"gen/.mise/tasks/BUILD.bazel",
	"gen/.mise/tasks/gen-drift.clj",
	"gen/.mise/tasks/gen-sync.clj",
]
