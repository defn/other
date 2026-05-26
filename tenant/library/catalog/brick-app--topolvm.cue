@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/topolvm": {
		path:       "tenant/library/app/topolvm"
		slug:       "app--topolvm"
		kind:       "component"
		desc:       "TopoLVM dynamic LVM provisioner"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
