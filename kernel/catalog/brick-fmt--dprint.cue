@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/dprint": {
		path: "kernel/fmt/dprint"
		slug: "fmt--dprint"
		kind: "component"
		reads: []
		writes: []
		desc:       "Dockerfile formatter (dprint)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
