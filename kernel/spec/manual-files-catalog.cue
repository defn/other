@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/catalog/ -- shared catalog files.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: catalog: [
	"kernel/spec/manual-files-catalog.cue",
	"kernel/catalog/BUILD.bazel",
	"kernel/catalog/apps.cue",
	"kernel/catalog/aws-tofu-apps.cue",
	"kernel/catalog/aws.cue",
	"kernel/catalog/bots.cue",
	"kernel/catalog/bricks.cue",
	"kernel/catalog/catalog.cue",
	"kernel/catalog/checks.cue",
	"kernel/catalog/formatters.cue",
	"kernel/catalog/gen-crds-apps.cue",
	"kernel/catalog/mirror.cue",
	"kernel/catalog/skills.cue",
	"kernel/catalog/mirrors.cue",
	"kernel/catalog/shared-bricks.cue",
]
