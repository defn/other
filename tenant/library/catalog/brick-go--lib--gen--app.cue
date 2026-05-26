@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/app": {
		path:       "tenant/library/go/lib/gen/app"
		slug:       "go--lib--gen--app"
		kind:       "component"
		desc:       "app"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
