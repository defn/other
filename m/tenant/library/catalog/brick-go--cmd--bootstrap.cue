@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/bootstrap": {
		path:       "tenant/library/go/cmd/bootstrap"
		slug:       "go--cmd--bootstrap"
		kind:       "component"
		desc:       "bootstrap"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		stamp_type: "go-cmd"
	}
}
