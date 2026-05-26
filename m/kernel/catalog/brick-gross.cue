@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/gross": {
		path: "kernel/gross"
		slug: "gross"
		kind: "component"
		reads: []
		writes: []
		desc: "temporary files pending proper home"
	}
}
