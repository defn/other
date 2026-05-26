@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/arc-crds": {
		path:       "tenant/library/app/arc-crds"
		slug:       "app--arc-crds"
		kind:       "component"
		desc:       "Actions Runner Controller CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
