@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/tailscale-dns-policy": {
		path:       "tenant/library/app/tailscale-dns-policy"
		slug:       "app--tailscale-dns-policy"
		kind:       "component"
		desc:       "Kyverno policy to generate wildcard DNS from Tailscale IP"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
