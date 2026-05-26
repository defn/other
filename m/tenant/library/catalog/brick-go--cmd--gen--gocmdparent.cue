@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/gocmdparent": {
		path:       "tenant/library/go/cmd/gen/gocmdparent"
		slug:       "go--cmd--gen--gocmdparent"
		kind:       "component"
		desc:       "gocmdparent"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
