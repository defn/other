@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: airef/ files.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when multiple bricks
// claim conventions concurrently.
//
// airef/ holds cross-cutting advice ("how to do things") -- the
// counterpart to aidr/ (chronological decisions). See
// kernel/catalog/brick-airef.cue for the brick declaration and
// airef/BUILD.bazel for the directory's Bazel wiring.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-airef": [
	"kernel/spec/convention-contracts-airef.cue",
]

// ---- airef/ -- NNNNN-<slug>.md --------------------------------------

generators: airef: {
	generator: "airef"
	source:    "(convention-based; no Go generator)"
	reason:    "airef entries follow the NNNNN-<slug>.md naming convention; every file matching that pattern is claimed by convention alone. Misnamed files become orphans, which is the intended signal."
	read_from: {
		lattice: ["tree.dirs.m.dirs.airef"]
	}
	related_aidr: [62, 66]
	paths: [
		for name, f in tree.dirs.m.dirs.airef.files
		if f.type == "file"
		if name =~ "^[0-9]{5}-[a-z0-9-]+\\.md$" {"airef/\(name)"},
	]
}
