@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: skills.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083.
// Per AIDR-00083's lazy-shard policy, kernel/catalog/skills.cue is
// sharded per-skill (skills-<name>.cue) so adding a skill is a
// single-file write that doesn't collide with sibling skill
// additions. Each shard contributes to the `skills` map via CUE
// struct unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-skills": [
	"kernel/spec/convention-contracts-skills.cue",
]

// ---- kernel/catalog/skills-*.cue -- one per skill instance ---------
//
// Each skill brick (root/skills/sp-<name>/) contributes its catalog
// metadata in kernel/catalog/skills-<name>.cue. The legacy
// kernel/catalog/skills.cue holds the schema constraint only and is
// claimed via manual-files (catalog section).

generators: skillscatalog: {
	generator: "skillscatalog"
	source:    "(convention-based; no Go generator)"
	reason:    "skill instance metadata is sharded per-skill into kernel/catalog/skills-<name>.cue (AIDR-00083 leaves-into-branches). The base skills.cue holds schema only."
	read_from: {
		lattice: ["tree.dirs.m.dirs.kernel.dirs.catalog"]
	}
	related_aidr: [62, 66, 83]
	paths: [
		for name, f in tree.dirs.m.dirs.kernel.dirs.catalog.files
		if f.type == "file"
		if name =~ "^skills-[a-z][a-z0-9-]*\\.cue$" {"kernel/catalog/\(name)"},
	]
}
