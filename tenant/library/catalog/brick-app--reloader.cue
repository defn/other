@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/reloader": {
		path:       "tenant/library/app/reloader"
		slug:       "app--reloader"
		kind:       "component"
		desc:       "ConfigMap/Secret change rollouts"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
