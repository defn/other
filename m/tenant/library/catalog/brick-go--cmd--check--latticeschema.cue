@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/check/latticeschema": {
		path:       "tenant/library/go/cmd/check/latticeschema"
		slug:       "go--cmd--check--latticeschema"
		kind:       "component"
		desc:       "latticeschema"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/check"
		stamp_type: "go-cmd"
	}
}
