@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/controllers": {
		path:       "v/galleybytes--terraform-operator/pkg/controllers"
		slug:       "v--galleybytes--terraform-operator--pkg--controllers"
		kind:       "component"
		desc:       "terraform reconciler controller"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
