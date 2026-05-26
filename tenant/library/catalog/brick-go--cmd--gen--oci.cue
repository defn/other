@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/oci": {
		path:       "tenant/library/go/cmd/gen/oci"
		slug:       "go--cmd--gen--oci"
		kind:       "component"
		desc:       "oci"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
