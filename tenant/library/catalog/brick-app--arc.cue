@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/arc": {
		path:       "tenant/library/app/arc"
		slug:       "app--arc"
		kind:       "component"
		desc:       "Actions Runner Controller v2 operator"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
