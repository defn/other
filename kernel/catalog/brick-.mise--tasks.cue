@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	".mise/tasks": {
		path: ".mise/tasks"
		slug: ".mise--tasks"
		kind: "component"
		reads: []
		writes: []
		desc: "mise task scripts"
	}
}
