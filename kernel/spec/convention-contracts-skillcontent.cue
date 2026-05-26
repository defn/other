@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: skillcontent.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

import "list"

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-skillcontent": [
	"kernel/spec/convention-contracts-skillcontent.cue",
]

// Top-level skill files (SKILL.md and any legacy helper markdown
// or scripts at the brick root during migration).
_skillContentTopPaths: [
	for name, skill in tree.dirs.m.dirs.root.dirs.skills.dirs
	if name =~ "^sp-"
	if skill.files != _|_
	for fname, f in skill.files
	if f.type == "file"
	if fname != "BUILD.bazel"
	if fname != "dispatch.cue" {"root/skills/\(name)/\(fname)"},
]

// Helper subdir files (scripts, references, prompts, examples)
// plus, during migration, any legacy upstream subdir.
_skillContentSubPaths: [
	for name, skill in tree.dirs.m.dirs.root.dirs.skills.dirs
	if name =~ "^sp-"
	if skill.dirs != _|_
	for sdName, sd in skill.dirs
	if sd.files != _|_
	for fname, f in sd.files
	if f.type == "file"
	if fname != "BUILD.bazel" {"root/skills/\(name)/\(sdName)/\(fname)"},
]

// ---- root/skills/ -- skill bricks managed by the skill Midas -------
//
// Each sp-* dir holds a hand-edited SKILL.md plus open-ended helper
// content under one of four named subdirs (scripts, references,
// prompts, examples). BUILD.bazel files at the brick root and per
// subdir are stamped by go/lib/gen/skill (claimed there).
// Top-level helper files (anything other than SKILL.md / BUILD.bazel)
// are also matched here, which currently captures legacy upstream
// content under the forked superpowers skills. Once the migration
// is complete and only Midas-stamped skills remain, the schema
// closes (manifest.cue #RootSkillsSkill) and this convention can
// tighten to SKILL.md only.

generators: skillcontent: {
	generator: "skillcontent"
	source:    "(convention-based; no Go generator)"
	reason:    "every file under root/skills/<name>/ that isn't BUILD.bazel is hand-edited skill content (SKILL.md plus optional helper material in scripts/references/prompts/examples). BUILD.bazel files are claimed by go/lib/gen/skill."
	read_from: {
		lattice: ["tree.dirs.m.dirs.root.dirs.skills"]
	}
	related_aidr: [62, 66]
	paths: list.Concat([_skillContentTopPaths, _skillContentSubPaths])
}
