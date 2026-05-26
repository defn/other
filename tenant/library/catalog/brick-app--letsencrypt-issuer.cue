@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/letsencrypt-issuer": {
		path:       "tenant/library/app/letsencrypt-issuer"
		slug:       "app--letsencrypt-issuer"
		kind:       "component"
		desc:       "Let's Encrypt ClusterIssuer + wildcard Certificate"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
