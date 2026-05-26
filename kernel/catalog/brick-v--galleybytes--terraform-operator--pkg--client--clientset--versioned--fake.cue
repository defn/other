@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/fake": {
		path:       "v/galleybytes--terraform-operator/pkg/client/clientset/versioned/fake"
		slug:       "v--galleybytes--terraform-operator--pkg--client--clientset--versioned--fake"
		kind:       "component"
		desc:       "terraform fake clientset"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
