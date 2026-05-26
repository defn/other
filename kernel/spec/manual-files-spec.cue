@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/spec/ -- spec dir manual files (incl. manual-files shards themselves).
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: spec: [
	"kernel/spec/manual-files-spec.cue",
	"kernel/spec/BUILD.bazel",
	"kernel/spec/brick-collision-vet-test.clj",
	"kernel/spec/contracts-schema.cue",
	"kernel/spec/contracts-vet-test.clj",
	"kernel/spec/cross-tenant-lit-vet-test.clj",
	"kernel/spec/empty-tenant-probe-test.clj",
	"kernel/spec/fork-smoke-test.clj",
	"kernel/spec/gen-files.txt",
	"kernel/spec/known-shared.cue",
	"kernel/spec/lattice-schema-test.clj",
	"kernel/spec/lattice-schema.cue",
	"kernel/spec/lattice.cue",
	"kernel/spec/dispatch/BUILD.bazel",
	"kernel/spec/dispatch/dispatch_plan.cue",
	"kernel/spec/mise.toml",
	"kernel/spec/sync-files.txt",
	"kernel/spec/tenant-stamp-smoke-test.clj",
]
