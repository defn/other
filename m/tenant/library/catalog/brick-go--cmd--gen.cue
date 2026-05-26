@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen": {
		path:       "tenant/library/go/cmd/gen"
		slug:       "go--cmd--gen"
		kind:       "component"
		desc:       "gen"
		implements: "kernel/interface/go-cmd-parent"
		reads: []
		writes: []
		stamp_type: "go-cmd-parent"
	}
}
