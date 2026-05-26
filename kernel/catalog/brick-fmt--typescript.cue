@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/typescript": {
		path: "kernel/fmt/typescript"
		slug: "fmt--typescript"
		kind: "component"
		reads: []
		writes: []
		desc:       "TypeScript formatter (biome)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
