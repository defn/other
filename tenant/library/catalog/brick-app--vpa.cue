@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/vpa": {
		path:       "tenant/library/app/vpa"
		slug:       "app--vpa"
		kind:       "component"
		desc:       "Vertical Pod Autoscaler"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
