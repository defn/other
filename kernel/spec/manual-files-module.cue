@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/module/ -- tofu module BUILD.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: module: [
	"kernel/spec/manual-files-module.cue",
	"kernel/module/BUILD.bazel",
]
