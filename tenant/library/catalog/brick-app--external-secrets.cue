@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/external-secrets": {
		path:       "tenant/library/app/external-secrets"
		slug:       "app--external-secrets"
		kind:       "component"
		desc:       "External Secrets Operator"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
