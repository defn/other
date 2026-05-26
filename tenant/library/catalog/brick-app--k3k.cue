@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/k3k": {
		path:       "tenant/library/app/k3k"
		slug:       "app--k3k"
		kind:       "component"
		desc:       "Rancher k3k -- Kubernetes-in-Kubernetes"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
