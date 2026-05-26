@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/dex": {
		path:       "tenant/library/app/dex"
		slug:       "app--dex"
		kind:       "component"
		desc:       "Dex OIDC identity provider"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
