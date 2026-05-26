@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/speclattice": {
		path:       "tenant/library/go/cmd/gen/speclattice"
		slug:       "go--cmd--gen--speclattice"
		kind:       "component"
		desc:       "speclattice"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
