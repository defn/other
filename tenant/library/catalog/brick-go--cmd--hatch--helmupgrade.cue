@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/hatch/helmupgrade": {
		path:       "tenant/library/go/cmd/hatch/helmupgrade"
		slug:       "go--cmd--hatch--helmupgrade"
		kind:       "component"
		desc:       "helm-upgrade"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/hatch"
		stamp_type: "go-cmd"
	}
}
