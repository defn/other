@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/.mise/tasks": {
		path: "kernel/fmt/.mise/tasks"
		slug: "fmt--.mise--tasks"
		kind: "component"
		reads: []
		writes: []
		desc: "formatting mise tasks"
	}
}
