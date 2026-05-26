@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"aidr": {
		path: "aidr"
		slug: "aidr"
		kind: "component"
		reads: []
		writes: []
		desc: "AI decision records"
	}
}
