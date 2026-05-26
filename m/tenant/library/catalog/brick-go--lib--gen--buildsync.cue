@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/buildsync": {
		path:       "tenant/library/go/lib/gen/buildsync"
		slug:       "go--lib--gen--buildsync"
		kind:       "component"
		desc:       "buildsync"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
