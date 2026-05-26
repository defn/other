@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: .devcontainer/ -- devcontainer scaffolding.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: devcontainer: [
	"kernel/spec/manual-files-devcontainer.cue",
	".devcontainer/.zsh-entrypoint",
	".devcontainer/.zshrc",
	".devcontainer/BUILD.bazel",
	".devcontainer/devcontainer.json",
	".devcontainer/docker-compose.macos.yml",
	".devcontainer/docker-compose.yml",
	".devcontainer/init-host.clj",
	".devcontainer/post-attach.clj",
	".devcontainer/post-start.clj",
]
