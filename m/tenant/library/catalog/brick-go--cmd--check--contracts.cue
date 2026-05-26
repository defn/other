@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/check/contracts": {
		path:       "tenant/library/go/cmd/check/contracts"
		slug:       "go--cmd--check--contracts"
		kind:       "component"
		desc:       "contracts"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/check"
		stamp_type: "go-cmd"
	}
}
