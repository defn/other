@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/k3k-crds": {
		path:       "tenant/library/app/k3k-crds"
		slug:       "app--k3k-crds"
		kind:       "component"
		desc:       "k3k CRDs (Cluster, VirtualClusterPolicy)"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
