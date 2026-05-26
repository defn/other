@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/golib": {
		path:       "tenant/library/go/lib/gen/golib"
		slug:       "go--lib--gen--golib"
		kind:       "component"
		desc:       "golib"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
