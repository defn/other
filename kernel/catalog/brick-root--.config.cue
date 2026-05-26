@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"root/.config": {
		path: "root/.config"
		slug: "root--.config"
		kind: "component"
		reads: []
		writes: []
		desc: "starship prompt configuration"
	}
}
