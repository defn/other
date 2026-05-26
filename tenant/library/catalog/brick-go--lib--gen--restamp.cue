@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/restamp": {
		path:       "tenant/library/go/lib/gen/restamp"
		slug:       "go--lib--gen--restamp"
		kind:       "component"
		desc:       "restamp"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
