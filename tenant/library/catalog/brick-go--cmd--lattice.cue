@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/lattice": {
		path:       "tenant/library/go/cmd/lattice"
		slug:       "go--cmd--lattice"
		kind:       "component"
		desc:       "lattice"
		implements: "kernel/interface/go-cmd-parent"
		reads: []
		writes: []
		stamp_type: "go-cmd-parent"
	}
}
