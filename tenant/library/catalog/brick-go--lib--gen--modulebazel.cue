@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/modulebazel": {
		path:       "tenant/library/go/lib/gen/modulebazel"
		slug:       "go--lib--gen--modulebazel"
		kind:       "component"
		desc:       "modulebazel"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
