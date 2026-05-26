@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/metrics-server": {
		path:       "tenant/library/app/metrics-server"
		slug:       "app--metrics-server"
		kind:       "component"
		desc:       "Cluster resource metrics API"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
