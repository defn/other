@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/golib": {
		path:       "tenant/library/go/cmd/stamp/golib"
		slug:       "go--cmd--stamp--golib"
		kind:       "component"
		desc:       "golib"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
