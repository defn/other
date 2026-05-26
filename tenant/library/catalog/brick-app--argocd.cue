@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/argocd": {
		path:       "tenant/library/app/argocd"
		slug:       "app--argocd"
		kind:       "component"
		desc:       "ArgoCD GitOps controller"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
