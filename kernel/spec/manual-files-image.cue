@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/image/ -- container/machine image scaffolding.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: image: [
	"kernel/spec/manual-files-image.cue",
	"kernel/image/BUILD.bazel",
	"kernel/image/docker/BUILD.bazel",
	"kernel/image/packer/BUILD.bazel",
	"kernel/image/packer/coder/BUILD.bazel",
	"kernel/image/packer/coder/coder.pkr.hcl",
	"kernel/image/packer/coder/install-packer.sh",
]
