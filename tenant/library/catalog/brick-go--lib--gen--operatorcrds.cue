@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/operatorcrds": {
		path:       "tenant/library/go/lib/gen/operatorcrds"
		slug:       "go--lib--gen--operatorcrds"
		kind:       "component"
		desc:       "operator CRD generation from Go types"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
