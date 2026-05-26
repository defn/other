@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/cloudnative-pg-crds": {
		path:       "tenant/library/app/cloudnative-pg-crds"
		slug:       "app--cloudnative-pg-crds"
		kind:       "component"
		desc:       "CloudNativePG CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
