@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/packer": {
		path: "kernel/image/packer"
		slug: "image--packer"
		kind: "branch"
		reads: []
		writes: []
		desc: "Packer machine images"
		composes: [
			"kernel/image/packer/coder",
		]
	}
}
