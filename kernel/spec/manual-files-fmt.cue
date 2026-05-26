@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/fmt/ -- formatter task scaffolding.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: fmt: [
	"kernel/spec/manual-files-fmt.cue",
	"kernel/fmt/.mise/tasks/BUILD.bazel",
	"kernel/fmt/.mise/tasks/fmt-check.clj",
	"kernel/fmt/.mise/tasks/fmt-cljstyle.clj",
	"kernel/fmt/.mise/tasks/fmt-exec-check.clj",
	"kernel/fmt/.mise/tasks/fmt-google-java-format.clj",
	"kernel/fmt/BUILD.bazel",
]
