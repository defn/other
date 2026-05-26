@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/schema": {
		path: "kernel/schema"
		slug: "schema"
		kind: "interface"
		reads: []
		writes: []
		desc: "type definitions and version pins"
	}
}
