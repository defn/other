@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: nono/ -- nono sandbox profiles.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: nono: [
	"kernel/spec/manual-files-nono.cue",
	"nono/BUILD.bazel",
	"nono/bazel.json",
	"nono/claude.json",
	"nono/go.json",
	"nono/mise.json",
	"nono/node.json",
	"nono/npm-write.json",
	"nono/npm.json",
	"nono/pnpm-write.json",
	"nono/pnpm.json",
	"nono/python.json",
]
