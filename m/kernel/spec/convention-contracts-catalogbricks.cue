@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: catalogbricks.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-catalogbricks": [
	"kernel/spec/convention-contracts-catalogbricks.cue",
]

generators: catalogbricks: {
	generator: "catalogbricks"
	source:    "(convention-based; no Go generator)"
	reason:    "kernel/catalog/brick-*.cue follows brick-<path-with-dashes>.cue. restamp owns stamped bricks; this contract owns the rest (interfaces, kits, raw and gen-owned components). Stamped files are excluded by filename-set filter so no multi-writer."
	read_from: {
		lattice: ["tree.dirs.m.dirs.kernel.dirs.catalog"]
	}
	related_aidr: [62, 66]
	paths: [
		for name, f in tree.dirs.m.dirs.kernel.dirs.catalog.files
		if f.type == "file"
		if name =~ "^brick-.+\\.cue$"
		if _restampOwnedFilenames[name] == _|_
		if _appOwnedFilenames[name] == _|_ {"kernel/catalog/\(name)"},
	]
}
