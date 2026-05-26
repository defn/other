@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/apis": {
		path:       "v/galleybytes--terraform-operator/pkg/apis"
		slug:       "v--galleybytes--terraform-operator--pkg--apis"
		kind:       "component"
		desc:       "terraform API scheme registration"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
