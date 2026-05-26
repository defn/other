@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/temporal": {
		path:       "tenant/library/app/temporal"
		slug:       "app--temporal"
		kind:       "component"
		desc:       "Temporal workflow engine"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
