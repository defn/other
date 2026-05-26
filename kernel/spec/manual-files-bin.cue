@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: bin/ -- repo-root bin/ scripts.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: bin: [
	"kernel/spec/manual-files-bin.cue",
	"bin/BUILD.bazel",
	"bin/bazel-runner",
	"bin/bbs",
	"bin/yae",
	"bin/bootstrap-bazelrc",
	"bin/defn",
	"bin/k3k",
]
