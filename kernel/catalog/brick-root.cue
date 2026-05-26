@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"root": {
		path: "root"
		slug: "root"
		kind: "component"
		reads: []
		writes: []
		desc: "project root files (symlinked from $HOME)"
	}
}
