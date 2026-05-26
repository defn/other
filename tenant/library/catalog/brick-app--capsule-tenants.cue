@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/capsule-tenants": {
		path:       "tenant/library/app/capsule-tenants"
		slug:       "app--capsule-tenants"
		kind:       "component"
		desc:       "Capsule Tenant definitions for infra namespaces"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
