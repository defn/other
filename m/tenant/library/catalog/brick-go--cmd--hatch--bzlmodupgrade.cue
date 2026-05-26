@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/hatch/bzlmodupgrade": {
		path:       "tenant/library/go/cmd/hatch/bzlmodupgrade"
		slug:       "go--cmd--hatch--bzlmodupgrade"
		kind:       "component"
		desc:       "bzlmod-upgrade"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/hatch"
		stamp_type: "go-cmd"
	}
}
