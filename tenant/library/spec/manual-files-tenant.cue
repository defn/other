@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: tenant/library/ -- per-tenant configuration.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. Owned by tenant/library/ and projected into
// kernel/spec/contracts via the tenant-spec overlay (AIDR-00138 D5.2,
// AIDR-00145 D5.2). See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: "tenant-library": [
	"tenant/library/spec/manual-files-tenant.cue",
	"tenant/library/spec/manual-files-tenant-catalogs.cue",
	"tenant/library/spec/BUILD.bazel",
	"tenant/library/BUILD.bazel",
	"tenant/library/aws/BUILD.bazel",
	"tenant/library/env/BUILD.bazel",
	"tenant/library/go/BUILD.bazel",
	"tenant/library/infra/.mise/tasks/BUILD.bazel",
	"tenant/library/infra/BUILD.bazel",
	"tenant/library/infra/mise.toml",
]
