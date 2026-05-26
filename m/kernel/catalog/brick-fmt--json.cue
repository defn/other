@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/json": {
		path: "kernel/fmt/json"
		slug: "fmt--json"
		kind: "component"
		reads: []
		writes: []
		desc:       "JSON formatter (biome)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
