@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/gocmdparent": {
		path:       "tenant/library/go/cmd/stamp/gocmdparent"
		slug:       "go--cmd--stamp--gocmdparent"
		kind:       "component"
		desc:       "gocmdparent"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
