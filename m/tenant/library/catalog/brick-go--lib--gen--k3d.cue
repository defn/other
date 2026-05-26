@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/k3d": {
		path:       "tenant/library/go/lib/gen/k3d"
		slug:       "go--lib--gen--k3d"
		kind:       "component"
		desc:       "k3d"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
