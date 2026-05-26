@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/gocmdcue": {
		path:       "tenant/library/go/cmd/gen/gocmdcue"
		slug:       "go--cmd--gen--gocmdcue"
		kind:       "component"
		desc:       "gocmdcue"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
