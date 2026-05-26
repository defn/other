@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/scheme": {
		path:       "v/galleybytes--terraform-operator/pkg/client/clientset/versioned/scheme"
		slug:       "v--galleybytes--terraform-operator--pkg--client--clientset--versioned--scheme"
		kind:       "component"
		desc:       "terraform clientset scheme"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
