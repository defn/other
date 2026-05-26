@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/gocmd": {
		path:       "tenant/library/go/cmd/stamp/gocmd"
		slug:       "go--cmd--stamp--gocmd"
		kind:       "component"
		desc:       "gocmd"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
