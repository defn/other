@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/keda": {
		path:       "tenant/library/app/keda"
		slug:       "app--keda"
		kind:       "component"
		desc:       "Event-driven autoscaling"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
