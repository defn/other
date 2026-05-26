@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/hatch": {
		path:       "tenant/library/go/cmd/hatch"
		slug:       "go--cmd--hatch"
		kind:       "component"
		desc:       "hatch"
		implements: "kernel/interface/go-cmd-parent"
		reads: []
		writes: []
		stamp_type: "go-cmd-parent"
	}
}
