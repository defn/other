@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/arc-runners": {
		path:       "tenant/library/app/arc-runners"
		slug:       "app--arc-runners"
		kind:       "component"
		desc:       "GitHub Actions runner scale sets"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
