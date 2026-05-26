@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/redis-operator-crds": {
		path:       "tenant/library/app/redis-operator-crds"
		slug:       "app--redis-operator-crds"
		kind:       "component"
		desc:       "Redis Operator CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
