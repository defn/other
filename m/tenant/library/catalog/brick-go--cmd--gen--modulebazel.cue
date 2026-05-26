@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/modulebazel": {
		path:       "tenant/library/go/cmd/gen/modulebazel"
		slug:       "go--cmd--gen--modulebazel"
		kind:       "component"
		desc:       "modulebazel"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
