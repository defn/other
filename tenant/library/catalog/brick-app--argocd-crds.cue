@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/argocd-crds": {
		path:       "tenant/library/app/argocd-crds"
		slug:       "app--argocd-crds"
		kind:       "component"
		desc:       "ArgoCD CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
