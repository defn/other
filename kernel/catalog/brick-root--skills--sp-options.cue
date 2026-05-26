@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"root/skills/sp-options": {
		path:       "root/skills/sp-options"
		slug:       "root--skills--sp-options"
		kind:       "component"
		desc:       "Supervisory layer: dialogue with user, write options/spec/plan as AIDR"
		implements: "kernel/interface/skill"
		reads: []
		writes: []
		stamp_type: "skill"
	}
}
