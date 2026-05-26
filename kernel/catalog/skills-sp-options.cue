@experiment(aliasv2,explicitopen,shortcircuit,try)

// Skill instance: sp-options.
//
// Per-skill catalog shard per AIDR-00083.

package catalog

skills: "sp-options": {
	name:        "sp-options"
	description: "Supervisory layer: dialogue with user, write options/spec/plan as AIDR"
	path:        "root/skills/sp-options"
	subdirs: ["prompts"]
}
