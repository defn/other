@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/traefik-crds": {
		path:       "tenant/library/app/traefik-crds"
		slug:       "app--traefik-crds"
		kind:       "component"
		desc:       "Traefik CRDs (IngressRoute, Middleware, etc.)"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
