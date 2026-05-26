@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/docker/edge": {
		path: "kernel/image/docker/edge"
		slug: "image--docker--edge"
		kind: "component"
		reads: []
		writes: []
		desc:       "edge devcontainer image"
		implements: "kernel/interface/image"
		stamp_type: "gen"
	}
}
