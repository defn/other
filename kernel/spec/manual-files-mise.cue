@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: .mise/tasks/ -- mise task BUILD files.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: mise: [
	"kernel/spec/manual-files-mise.cue",
	".mise/tasks/BUILD.bazel",
	".mise/tasks/claude.go",
	".mise/tasks/dev-base.go",
	".mise/tasks/dev-bazel-remote.go",
	".mise/tasks/dev-cache.go",
	".mise/tasks/dev-edge.go",
	".mise/tasks/dev-install.go",
	".mise/tasks/dev-postgres.go",
	".mise/tasks/dev-push.go",
	".mise/tasks/dev-rebase.go",
	".mise/tasks/dev-redis.go",
	".mise/tasks/dev-registry.go",
	".mise/tasks/dev-reload.go",
	".mise/tasks/dev-sync.go",
	".mise/tasks/dev-uninstall.go",
	".mise/tasks/normalize-modes.go",
	".mise/tasks/opencode.go",
]
