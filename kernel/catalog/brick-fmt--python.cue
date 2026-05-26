@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/python": {
		path: "kernel/fmt/python"
		slug: "fmt--python"
		kind: "component"
		reads: []
		writes: []
		desc:       "Python formatter (ruff)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
