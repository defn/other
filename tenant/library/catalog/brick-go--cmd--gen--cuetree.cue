@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/cuetree": {
		path:       "tenant/library/go/cmd/gen/cuetree"
		slug:       "go--cmd--gen--cuetree"
		kind:       "component"
		desc:       "cuetree"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
