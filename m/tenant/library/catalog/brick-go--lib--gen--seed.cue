@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/seed": {
		path:       "tenant/library/go/lib/gen/seed"
		slug:       "go--lib--gen--seed"
		kind:       "component"
		desc:       "seed"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
