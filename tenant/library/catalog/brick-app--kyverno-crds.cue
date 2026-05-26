@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/kyverno-crds": {
		path:       "tenant/library/app/kyverno-crds"
		slug:       "app--kyverno-crds"
		kind:       "component"
		desc:       "Kyverno CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
