@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: skill generator.
//
// Traceability:
//   Go source:      go/lib/gen/skill/skill.go
//   Reads catalogs: catalog.skills
//   Template:       kernel/interface/skill/templates.cue
//
// Why these files exist: each skill brick has BUILD.bazel at its
// root, plus one BUILD.bazel per declared subdir (scripts,
// references, prompts, examples). SKILL.md is hand-edited and
// claimed manually; subdir content is open-ended and claimed by the
// `skillcontent` Pattern C convention contract.
//
// See AIDR-00062 (generator contracts).

package contracts

import "list"

bricks: [string]: {
	path:       string
	implements: string | *""
	...
}

skills: [string]: {
	path: string
	subdirs?: [...string]
	...
}

// Top-level BUILD.bazel for each skill brick.
_skillRootPaths: [
	for _, b in bricks
	if b.implements == "kernel/interface/skill" {"\(b.path)/BUILD.bazel"},
]

// Per-subdir BUILD.bazel for each declared helper subdir.
_skillSubdirPaths: [
	for _, s in skills if s.subdirs != _|_
	for sd in s.subdirs {"\(s.path)/\(sd)/BUILD.bazel"},
]

generators: skill: {
	generator: "skill"
	source:    "tenant/library/go/lib/gen/skill"
	reason:    "stamps per-skill brick dirs (root BUILD.bazel + per-subdir BUILD.bazel) from catalog.skills"
	read_from: {
		catalog: ["skills"]
		paths: ["kernel/interface/skill/templates.cue"]
	}
	related_aidr: [62]
	paths: list.Concat([_skillRootPaths, _skillSubdirPaths])
}
