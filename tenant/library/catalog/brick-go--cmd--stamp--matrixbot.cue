@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/matrixbot": {
		path:       "tenant/library/go/cmd/stamp/matrixbot"
		slug:       "go--cmd--stamp--matrixbot"
		kind:       "component"
		desc:       "matrixbot"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
