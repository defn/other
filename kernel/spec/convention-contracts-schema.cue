@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: schema.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-schema": [
	"kernel/spec/convention-contracts-schema.cue",
]

// ---- kernel/schema/ -- <topic>.cue ----------------------------------

generators: schema: {
	generator: "schema"
	source:    "(convention-based; no Go generator)"
	reason:    "schema definitions under kernel/schema/ follow the <topic>.cue convention (lower-case, no dashes). The whole dir is hand-written CUE schema; the convention claim keeps the roster in sync with the filesystem and catches typos like Schema.CUE."
	read_from: {
		lattice: ["tree.dirs.m.dirs.kernel.dirs.schema"]
	}
	related_aidr: [62, 66]
	paths: [
		for name, f in tree.dirs.m.dirs.kernel.dirs.schema.files
		if f.type == "file"
		if name != "dispatch.cue"
		if name =~ "^[a-z][a-z0-9]*\\.cue$" {"kernel/schema/\(name)"},
	]
}
