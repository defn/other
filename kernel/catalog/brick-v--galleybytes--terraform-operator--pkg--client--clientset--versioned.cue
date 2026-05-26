@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned": {
		path:       "v/galleybytes--terraform-operator/pkg/client/clientset/versioned"
		slug:       "v--galleybytes--terraform-operator--pkg--client--clientset--versioned"
		kind:       "component"
		desc:       "terraform versioned clientset"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
