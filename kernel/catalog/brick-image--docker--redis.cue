@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/docker/redis": {
		path: "kernel/image/docker/redis"
		slug: "image--docker--redis"
		kind: "component"
		reads: []
		writes: []
		desc:       "redis container image"
		implements: "kernel/interface/image"
		stamp_type: "gen"
	}
}
