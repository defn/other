@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/redis-operator": {
		path:       "tenant/library/app/redis-operator"
		slug:       "app--redis-operator"
		kind:       "component"
		desc:       "OpsTree Redis operator"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
