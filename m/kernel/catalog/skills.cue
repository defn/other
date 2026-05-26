@experiment(aliasv2,explicitopen,shortcircuit,try)

// Schema constraints for the skill Midas. Skill instances live as
// bricks under m/root/skills/sp-<name>/; instance metadata is added
// per-skill by `defn stamp skill` into kernel/catalog/skills-<name>.cue
// (sharded per AIDR-00083 leaves-into-branches).
//
// This file holds only the schema constraint. Per-skill instance
// data lives in kernel/catalog/skills-<name>.cue, claimed by
// convention-contracts-skills.cue.
package catalog

import "github.com/defn/other/kernel/schema"

// Per-skill schema in kernel/schema/skill.cue.
//
// The skills map is keyed by skill name; the key == #Skill.name
// invariant is enforced by `defn stamp skill`, not by the schema.
skills: [string]: schema.#Skill
