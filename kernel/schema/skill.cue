@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #Skill defines a Claude Code skill instance.
//
// Each skill is a brick under m/root/skills/sp-<name>/. The skill body
// (frontmatter + markdown) lives in SKILL.md and is hand-edited.
// Variable helper content goes in one of four named subdirs whose
// content is open-ended and convention-claimed by Pattern C.
#Skill: {
	name:        =~"^sp-[a-z][a-z0-9-]*$" // brick name, must use sp- prefix
	description: !=""                     // human-facing summary (catalog-side)
	subdirs?: [...#SkillSubdir] // optional helper content layout
	path:                       string // brick path, e.g. "root/skills/sp-options"
}

// Imposed structure for skill helper content. Anything outside these
// four named subdirs (or SKILL.md / BUILD.bazel) fails the manifest.
#SkillSubdir: "scripts" | "references" | "prompts" | "examples"
