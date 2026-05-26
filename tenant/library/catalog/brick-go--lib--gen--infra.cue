@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/infra": {
		path:       "tenant/library/go/lib/gen/infra"
		slug:       "go--lib--gen--infra"
		kind:       "component"
		desc:       "infra"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
