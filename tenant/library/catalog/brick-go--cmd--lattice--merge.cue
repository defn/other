@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/lattice/merge": {
		path:       "tenant/library/go/cmd/lattice/merge"
		slug:       "go--cmd--lattice--merge"
		kind:       "component"
		desc:       "merge"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/lattice"
		stamp_type: "go-cmd"
	}
}
