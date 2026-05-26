@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/tofu": {
		path: "kernel/fmt/tofu"
		slug: "fmt--tofu"
		kind: "component"
		reads: []
		writes: []
		desc:       "Tofu formatter (opentofu fmt)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
