@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/k3d": {
		path:       "tenant/library/go/cmd/gen/k3d"
		slug:       "go--cmd--gen--k3d"
		kind:       "component"
		desc:       "k3d"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
