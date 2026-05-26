@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/oci": {
		path:       "tenant/library/go/lib/gen/oci"
		slug:       "go--lib--gen--oci"
		kind:       "component"
		desc:       "oci"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
