@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: root/ -- root profile content.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: root: [
	"kernel/spec/manual-files-root.cue",
	"root/.aws/BUILD.bazel",
	"root/.bash_entrypoint",
	"root/.bazelrc",
	"root/.config/BUILD.bazel",
	"root/.config/mise/BUILD.bazel",
	"root/.config/starship.toml",
	"root/.zshrc",
	"root/AGENTS.md",
	"root/BUILD.bazel",
	"root/LICENSE",
	"root/README.md",
	"root/skills.txt",
]
