@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/trust-manager": {
		path:       "tenant/library/app/trust-manager"
		slug:       "app--trust-manager"
		kind:       "component"
		desc:       "CA trust bundle distribution"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
