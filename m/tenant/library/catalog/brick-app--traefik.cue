@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/traefik": {
		path:       "tenant/library/app/traefik"
		slug:       "app--traefik"
		kind:       "component"
		desc:       "Traefik ingress controller"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
