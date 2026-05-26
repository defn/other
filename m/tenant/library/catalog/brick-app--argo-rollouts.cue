@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/argo-rollouts": {
		path:       "tenant/library/app/argo-rollouts"
		slug:       "app--argo-rollouts"
		kind:       "component"
		desc:       "Canary and blue-green deployments"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
