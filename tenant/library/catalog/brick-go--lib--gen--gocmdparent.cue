@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/gocmdparent": {
		path:       "tenant/library/go/lib/gen/gocmdparent"
		slug:       "go--lib--gen--gocmdparent"
		kind:       "component"
		desc:       "gocmdparent"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
