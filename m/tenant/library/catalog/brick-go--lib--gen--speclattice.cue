@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/speclattice": {
		path:       "tenant/library/go/lib/gen/speclattice"
		slug:       "go--lib--gen--speclattice"
		kind:       "component"
		desc:       "speclattice"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
