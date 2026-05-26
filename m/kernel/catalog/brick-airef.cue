@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"airef": {
		path: "airef"
		slug: "airef"
		kind: "component"
		reads: []
		writes: []
		desc: "AI reference -- cross-cutting advice on how to do things in this repo"
	}
}
