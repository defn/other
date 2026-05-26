@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: root/skills/ -- skill bricks BUILD.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: skills: [
	"kernel/spec/manual-files-skills.cue",
	"root/skills/BUILD.bazel",
]
