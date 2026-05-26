@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/shell": {
		path: "kernel/fmt/shell"
		slug: "fmt--shell"
		kind: "component"
		reads: []
		writes: []
		desc:       "Shell formatter (shfmt)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
