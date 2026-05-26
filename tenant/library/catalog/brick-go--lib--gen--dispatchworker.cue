@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/dispatchworker": {
		path:       "tenant/library/go/lib/gen/dispatchworker"
		slug:       "go--lib--gen--dispatchworker"
		kind:       "component"
		desc:       "dispatchworker"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
