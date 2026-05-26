@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/cert-manager-crds": {
		path:       "tenant/library/app/cert-manager-crds"
		slug:       "app--cert-manager-crds"
		kind:       "component"
		desc:       "cert-manager CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
