@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/utils": {
		path:       "v/galleybytes--terraform-operator/pkg/utils"
		slug:       "v--galleybytes--terraform-operator--pkg--utils"
		kind:       "component"
		desc:       "terraform operator utilities"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
