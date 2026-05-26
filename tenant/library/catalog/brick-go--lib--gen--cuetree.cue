@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/cuetree": {
		path:       "tenant/library/go/lib/gen/cuetree"
		slug:       "go--lib--gen--cuetree"
		kind:       "component"
		desc:       "cuetree"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
