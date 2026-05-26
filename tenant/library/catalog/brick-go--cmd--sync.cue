@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/sync": {
		path:       "tenant/library/go/cmd/sync"
		slug:       "go--cmd--sync"
		kind:       "component"
		desc:       "sync"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		stamp_type: "go-cmd"
	}
}
