@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/trust-manager-crds": {
		path:       "tenant/library/app/trust-manager-crds"
		slug:       "app--trust-manager-crds"
		kind:       "component"
		desc:       "trust-manager CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
