@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/karpenter": {
		path:       "tenant/library/app/karpenter"
		slug:       "app--karpenter"
		kind:       "component"
		desc:       "Karpenter node autoscaler"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
