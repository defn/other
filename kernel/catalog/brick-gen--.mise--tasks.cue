@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"gen/.mise/tasks": {
		path: "gen/.mise/tasks"
		slug: "gen--.mise--tasks"
		kind: "component"
		reads: []
		writes: []
		desc: "generation mise tasks"
	}
}
