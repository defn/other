@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/lattice": {
		path:       "tenant/library/go/lib/gen/lattice"
		slug:       "go--lib--gen--lattice"
		kind:       "component"
		desc:       "lattice"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
