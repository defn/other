@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/hatch/goupgrade": {
		path:       "tenant/library/go/cmd/hatch/goupgrade"
		slug:       "go--cmd--hatch--goupgrade"
		kind:       "component"
		desc:       "go-upgrade"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/hatch"
		stamp_type: "go-cmd"
	}
}
