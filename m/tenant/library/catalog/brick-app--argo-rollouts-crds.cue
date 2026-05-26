@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/argo-rollouts-crds": {
		path:       "tenant/library/app/argo-rollouts-crds"
		slug:       "app--argo-rollouts-crds"
		kind:       "component"
		desc:       "Argo Rollouts CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
