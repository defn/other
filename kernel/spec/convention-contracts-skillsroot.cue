@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: skillsroot.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-skillsroot": [
	"kernel/spec/convention-contracts-skillsroot.cue",
]

// ---- root/skills/ top-level files (LICENSE) ------------------------
//
// LICENSE.txt and BUILD.bazel directly under root/skills/ live above
// the per-skill bricks. BUILD.bazel is claimed by skill (its top-level
// rendering); LICENSE.txt is hand-written.

generators: skillsroot: {
	generator: "skillsroot"
	source:    "(convention-based; no Go generator)"
	reason:    "the root/skills/ directory carries an upstream MIT license file alongside the skill bricks. Hand-written; convention-claimed."
	read_from: {
		lattice: ["tree.dirs.m.dirs.root.dirs.skills"]
	}
	related_aidr: [62, 66]
	paths: [
		for name, f in tree.dirs.m.dirs.root.dirs.skills.files
		if f.type == "file"
		if name != "BUILD.bazel" {"root/skills/\(name)"},
	]
}
