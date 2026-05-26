@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/catalog": {
		path: "kernel/catalog"
		slug: "catalog"
		kind: "interface"
		reads: []
		writes: []
		desc: "resource inventories (clusters, images, bricks)"
	}
}
