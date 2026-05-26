@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: top-level repo files (.bazelrc, BUILD.bazel, go.sum, etc.).
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: "repo-root": [
	"kernel/spec/manual-files-repo-root.cue",
	".bazelignore",
	".bazelrc",
	".bazelrc.user-default",
	".bazelrc.user-devcontainer",
	".gitignore",
	".npmrc",
	"BUILD.bazel",
	"WORKSPACE",
	"WORKSPACE.bazel",
	"bb.edn",
	"dprint.json",
	"go.sum",
	"go.work.sum",
	"kernel/fmt.bzl",
	"kernel/tagged.bzl",
	"pnpm-lock.yaml",
	"tsconfig.json",
	"what is this file doing",
]
