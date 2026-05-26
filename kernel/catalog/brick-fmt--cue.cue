@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/cue": {
		path: "kernel/fmt/cue"
		slug: "fmt--cue"
		kind: "component"
		reads: []
		writes: []
		desc:       "CUE formatter (cue)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
