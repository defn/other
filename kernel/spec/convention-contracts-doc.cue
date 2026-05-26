@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: doc.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-doc": [
	"kernel/spec/convention-contracts-doc.cue",
]

// ---- kernel/doc/ -- BRICK-<topic>.md or similar markdown ------------

generators: doc: {
	generator: "doc"
	source:    "(convention-based; no Go generator)"
	reason:    "human docs under kernel/doc/ are markdown. Pattern claim catches non-markdown or oddly-named files."
	read_from: {
		lattice: ["tree.dirs.m.dirs.kernel.dirs.doc"]
	}
	related_aidr: [62, 66]
	paths: [
		for name, f in tree.dirs.m.dirs.kernel.dirs.doc.files
		if f.type == "file"
		if name =~ "^.+\\.md$" {"kernel/doc/\(name)"},
	]
}
