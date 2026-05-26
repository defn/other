@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	".devcontainer": {
		path: ".devcontainer"
		slug: ".devcontainer"
		kind: "component"
		reads: []
		writes: []
		desc: "devcontainer configuration"
	}
}
