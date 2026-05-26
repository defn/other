@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: tenant/ -- substrate-level entries only.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.
//
// Per AIDR-00145 D5.2, the per-tenant entries that used to live here
// were partitioned into tenant/<t>/spec/manual-files-tenant.cue
// (projected back via the tenant-spec overlay). This shard retains
// only the top-level substrate file that belongs to no single tenant.

package contracts

_manualFileShards: tenant: [
	"kernel/spec/manual-files-tenant.cue",
	"tenant/BUILD.bazel",
]
