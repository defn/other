@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/hatch/miseupgrade": {
		path:       "tenant/library/go/cmd/hatch/miseupgrade"
		slug:       "go--cmd--hatch--miseupgrade"
		kind:       "component"
		desc:       "mise-upgrade"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/hatch"
		stamp_type: "go-cmd"
	}
}
