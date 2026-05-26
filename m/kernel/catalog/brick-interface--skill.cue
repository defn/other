@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/skill": {
		path: "kernel/interface/skill"
		slug: "interface--skill"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Claude Code skill instance contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "skills"
	}
}
