@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1/fake": {
		path:       "v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1/fake"
		slug:       "v--galleybytes--terraform-operator--pkg--client--clientset--versioned--typed--tf--v1beta1--fake"
		kind:       "component"
		desc:       "terraform fake typed client"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
