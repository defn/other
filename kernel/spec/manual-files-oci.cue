@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/oci/ -- OCI external image BUILD.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: oci: [
	"kernel/spec/manual-files-oci.cue",
	"kernel/oci/BUILD.bazel",
]
