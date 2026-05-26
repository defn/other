@experiment(aliasv2,explicitopen,shortcircuit,try)

// Skill instance: sp-bricks.
//
// Per-skill catalog shard per AIDR-00083 (leaves-into-branches).
// Adding a skill is a single-file write; the base skills.cue holds
// only the schema constraint.

package catalog

skills: "sp-bricks": {
	name:        "sp-bricks"
	description: "Implementation layer: stamp -> hatch -> check; no deliberation"
	path:        "root/skills/sp-bricks"
}
