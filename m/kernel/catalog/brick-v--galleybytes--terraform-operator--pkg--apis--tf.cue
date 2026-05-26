@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/apis/tf": {
		path:       "v/galleybytes--terraform-operator/pkg/apis/tf"
		slug:       "v--galleybytes--terraform-operator--pkg--apis--tf"
		kind:       "component"
		desc:       "terraform API group"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
