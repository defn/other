@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/linkerd-crds": {
		path:       "tenant/library/app/linkerd-crds"
		slug:       "app--linkerd-crds"
		kind:       "component"
		desc:       "Linkerd CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
