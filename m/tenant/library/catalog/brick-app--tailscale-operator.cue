@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/tailscale-operator": {
		path:       "tenant/library/app/tailscale-operator"
		slug:       "app--tailscale-operator"
		kind:       "component"
		desc:       "Tailscale Kubernetes operator"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
