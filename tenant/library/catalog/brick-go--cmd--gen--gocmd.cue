@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/gocmd": {
		path:       "tenant/library/go/cmd/gen/gocmd"
		slug:       "go--cmd--gen--gocmd"
		kind:       "component"
		desc:       "gocmd"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
