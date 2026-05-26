@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/go": {
		path: "kernel/fmt/go"
		slug: "fmt--go"
		kind: "component"
		reads: []
		writes: []
		desc:       "Go formatter (gofmt)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
