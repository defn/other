@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: tenant/<t>/catalog/ BUILD files.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.
//
// Per AIDR-00145 D5.2, the per-tenant catalog BUILD.bazel entries
// were partitioned into tenant/<t>/spec/manual-files-tenant-catalogs.cue
// (projected back via the tenant-spec overlay). This shard retains
// only its own self-reference.

package contracts

_manualFileShards: "tenant-catalogs": [
	"kernel/spec/manual-files-tenant-catalogs.cue",
]
