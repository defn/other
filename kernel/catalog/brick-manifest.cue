@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/manifest": {
		path: "kernel/manifest"
		slug: "manifest"
		kind: "relationship"
		reads: []
		writes: []
		desc: "directory structure validation rules"
	}
}
