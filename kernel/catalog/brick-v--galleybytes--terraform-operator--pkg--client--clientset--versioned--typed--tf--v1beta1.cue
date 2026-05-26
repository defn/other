@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1": {
		path:       "v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1"
		slug:       "v--galleybytes--terraform-operator--pkg--client--clientset--versioned--typed--tf--v1beta1"
		kind:       "component"
		desc:       "terraform typed client"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
