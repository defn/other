@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: tenant/library/catalog/ BUILD files.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; owned by
// tenant/library/ and projected into kernel/spec/contracts via the
// tenant-spec overlay (AIDR-00138 D5.2, AIDR-00145 D5.2). See
// contracts-schema.cue for the _manualFileShards aggregation pattern.

package contracts

_manualFileShards: "tenant-catalogs-library": [
	"tenant/library/catalog/BUILD.bazel",
]
