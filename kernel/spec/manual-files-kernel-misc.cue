@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/ -- miscellaneous kernel content (BUILD, lib, etc.).
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: "kernel-misc": [
	"kernel/spec/manual-files-kernel-misc.cue",
	"kernel/BUILD.bazel",
	"kernel/doc/BUILD.bazel",
	"kernel/gen-versions/BUILD.bazel",
	"kernel/gross/BUILD.bazel",
	"kernel/gross/registry-ca.pem",
	"kernel/gross/registry-cert.pem",
	"kernel/gross/registry-key.pem",
	"kernel/helpers/BUILD.bazel",
	"kernel/helpers/bazel.cue",
	"kernel/lib/BUILD.bazel",
	"kernel/lib/defn.clj",
	"kernel/lib/devcontainer.clj",
	"kernel/manifest/BUILD.bazel",
	"kernel/manifest/manifest.cue",
	"kernel/schema/BUILD.bazel",
]
