@experiment(aliasv2,explicitopen,shortcircuit,try)

// Skill instance: sp-review.
//
// Per-skill catalog shard per AIDR-00083.

package catalog

skills: "sp-review": {
	name:        "sp-review"
	description: "Terminal layer: code + security review at brick fixed point -> review AIDR"
	path:        "root/skills/sp-review"
	subdirs: ["prompts"]
}
