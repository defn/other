@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/matrixbot": {
		path:       "tenant/library/go/cmd/gen/matrixbot"
		slug:       "go--cmd--gen--matrixbot"
		kind:       "component"
		desc:       "matrixbot"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
