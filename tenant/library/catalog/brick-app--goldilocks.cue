@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/goldilocks": {
		path:       "tenant/library/app/goldilocks"
		slug:       "app--goldilocks"
		kind:       "component"
		desc:       "VPA recommendations dashboard"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
