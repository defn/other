@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/docker/base": {
		path: "kernel/image/docker/base"
		slug: "image--docker--base"
		kind: "component"
		reads: []
		writes: []
		desc:       "base devcontainer image"
		implements: "kernel/interface/image"
		stamp_type: "gen"
	}
}
