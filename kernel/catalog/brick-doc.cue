@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/doc": {
		path: "kernel/doc"
		slug: "doc"
		kind: "component"
		reads: []
		writes: []
		desc: "documentation files"
	}
}
