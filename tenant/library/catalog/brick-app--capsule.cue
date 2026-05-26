@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/capsule": {
		path:       "tenant/library/app/capsule"
		slug:       "app--capsule"
		kind:       "component"
		desc:       "Multi-tenant namespace provisioning"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
