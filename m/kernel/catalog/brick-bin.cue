@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"bin": {
		path: "bin"
		slug: "bin"
		kind: "component"
		reads: []
		writes: []
		desc: "shebang wrappers"
	}
}
