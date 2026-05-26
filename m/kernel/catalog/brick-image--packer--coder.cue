@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/packer/coder": {
		path: "kernel/image/packer/coder"
		slug: "image--packer--coder"
		kind: "component"
		reads: []
		writes: []
		desc:       "Coder EC2 workspace AMI"
		implements: "kernel/interface/image"
		stamp_type: "gen"
	}
}
