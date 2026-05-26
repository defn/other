@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/external-secrets-crds": {
		path:       "tenant/library/app/external-secrets-crds"
		slug:       "app--external-secrets-crds"
		kind:       "component"
		desc:       "External Secrets Operator CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
