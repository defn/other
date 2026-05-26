@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/external-dns": {
		path:       "tenant/library/app/external-dns"
		slug:       "app--external-dns"
		kind:       "component"
		desc:       "Automatic DNS from ingress annotations"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
