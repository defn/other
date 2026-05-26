@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/check/crosstenantlit": {
		path:       "tenant/library/go/cmd/check/crosstenantlit"
		slug:       "go--cmd--check--crosstenantlit"
		kind:       "component"
		desc:       "crosstenantlit"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/check"
		stamp_type: "go-cmd"
	}
}
