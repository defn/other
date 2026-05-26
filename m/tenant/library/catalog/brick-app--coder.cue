@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/coder": {
		path:       "tenant/library/app/coder"
		slug:       "app--coder"
		kind:       "component"
		desc:       "Coder IDE workspace manager"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
