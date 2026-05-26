@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/docker/registry": {
		path: "kernel/image/docker/registry"
		slug: "image--docker--registry"
		kind: "component"
		reads: []
		writes: []
		desc:       "registry container image"
		implements: "kernel/interface/image"
		stamp_type: "gen"
	}
}
