@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"root/skills/sp-review": {
		path:       "root/skills/sp-review"
		slug:       "root--skills--sp-review"
		kind:       "component"
		desc:       "Terminal layer: code + security review at brick fixed point -> review AIDR"
		implements: "kernel/interface/skill"
		reads: []
		writes: []
		stamp_type: "skill"
	}
}
