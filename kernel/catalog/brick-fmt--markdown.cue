@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/markdown": {
		path: "kernel/fmt/markdown"
		slug: "fmt--markdown"
		kind: "component"
		reads: []
		writes: []
		desc:       "Markdown formatter (prettier)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
