@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/tailscale-operator-crds": {
		path:       "tenant/library/app/tailscale-operator-crds"
		slug:       "app--tailscale-operator-crds"
		kind:       "component"
		desc:       "Tailscale Operator CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
