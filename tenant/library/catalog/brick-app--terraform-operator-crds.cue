@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/terraform-operator-crds": {
		path:       "tenant/library/app/terraform-operator-crds"
		slug:       "app--terraform-operator-crds"
		kind:       "component"
		desc:       "Terraform Operator CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
