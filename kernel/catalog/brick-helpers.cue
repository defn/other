@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/helpers": {
		path: "kernel/helpers"
		slug: "helpers"
		kind: "component"
		reads: []
		writes: []
		desc: "standalone CUE helpers for template rendering"
	}
}
