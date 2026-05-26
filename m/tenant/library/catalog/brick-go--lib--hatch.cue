@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/hatch": {
		path:       "tenant/library/go/lib/hatch"
		slug:       "go--lib--hatch"
		kind:       "component"
		desc:       "hatch"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
