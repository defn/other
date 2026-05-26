@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/gocmdcue": {
		path:       "tenant/library/go/cmd/stamp/gocmdcue"
		slug:       "go--cmd--stamp--gocmdcue"
		kind:       "component"
		desc:       "gocmdcue"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
