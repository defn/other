@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/cert-manager": {
		path:       "tenant/library/app/cert-manager"
		slug:       "app--cert-manager"
		kind:       "component"
		desc:       "TLS certificate management"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
