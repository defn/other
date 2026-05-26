@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/check/brickcollision": {
		path:       "tenant/library/go/cmd/check/brickcollision"
		slug:       "go--cmd--check--brickcollision"
		kind:       "component"
		desc:       "brickcollision"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/check"
		stamp_type: "go-cmd"
	}
}
