@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image": {
		path: "kernel/image"
		slug: "image"
		kind: "branch"
		reads: []
		writes: []
		desc: "container and machine image instances"
		composes: [
			"kernel/image/docker",
			"kernel/image/packer",
		]
	}
}
