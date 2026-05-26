@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/keda-crds": {
		path:       "tenant/library/app/keda-crds"
		slug:       "app--keda-crds"
		kind:       "component"
		desc:       "KEDA CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
