@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/riverqueue": {
		path:       "tenant/library/app/riverqueue"
		slug:       "app--riverqueue"
		kind:       "component"
		desc:       "River Queue PostgreSQL database and web UI"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
