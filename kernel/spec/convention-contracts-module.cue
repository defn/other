@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: module.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-module": [
	"kernel/spec/convention-contracts-module.cue",
]

// ---- module/ -- BUILD.bazel + *.tf per terraform module ------------

generators: module: {
	generator: "module"
	source:    "(convention-based; no Go generator)"
	reason:    "each module/<name>/ terraform module has BUILD.bazel + hand-written .tf files (main.tf, outputs.tf, variables.tf). regions.gen.tf is claimed by infra (generator output) so the regex rejects the .gen.tf form to avoid multi-writer conflict."
	read_from: {
		lattice: ["tree.dirs.m.dirs.kernel.dirs.module"]
	}
	related_aidr: [62, 66]
	paths: [
		for modName, mod in tree.dirs.m.dirs.kernel.dirs.module.dirs
		if mod.files != _|_
		for name, f in mod.files
		if f.type == "file"
		// `^[a-z]+\.tf$` matches main.tf but NOT regions.gen.tf (two dots).
		if name =~ "^(BUILD\\.bazel|[a-z]+\\.tf)$" {"kernel/module/\(modName)/\(name)"},
	]
}
