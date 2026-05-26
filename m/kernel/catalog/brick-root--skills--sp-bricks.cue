@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"root/skills/sp-bricks": {
		path:       "root/skills/sp-bricks"
		slug:       "root--skills--sp-bricks"
		kind:       "component"
		desc:       "Implementation layer: stamp -> hatch -> check; no deliberation"
		implements: "kernel/interface/skill"
		reads: []
		writes: []
		stamp_type: "skill"
	}
}
