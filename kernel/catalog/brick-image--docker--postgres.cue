@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/docker/postgres": {
		path: "kernel/image/docker/postgres"
		slug: "image--docker--postgres"
		kind: "component"
		reads: []
		writes: []
		desc:       "postgres container image"
		implements: "kernel/interface/image"
		stamp_type: "gen"
	}
}
