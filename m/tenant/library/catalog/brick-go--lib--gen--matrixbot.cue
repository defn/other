@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/matrixbot": {
		path:       "tenant/library/go/lib/gen/matrixbot"
		slug:       "go--lib--gen--matrixbot"
		kind:       "component"
		desc:       "matrixbot"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
