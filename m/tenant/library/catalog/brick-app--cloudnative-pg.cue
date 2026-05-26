@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/cloudnative-pg": {
		path:       "tenant/library/app/cloudnative-pg"
		slug:       "app--cloudnative-pg"
		kind:       "component"
		desc:       "CloudNativePG PostgreSQL operator"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
