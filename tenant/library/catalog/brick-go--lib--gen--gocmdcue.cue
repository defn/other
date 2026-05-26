@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/gocmdcue": {
		path:       "tenant/library/go/lib/gen/gocmdcue"
		slug:       "go--lib--gen--gocmdcue"
		kind:       "component"
		desc:       "gocmdcue"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
