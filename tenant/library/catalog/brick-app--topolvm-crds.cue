@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/topolvm-crds": {
		path:       "tenant/library/app/topolvm-crds"
		slug:       "app--topolvm-crds"
		kind:       "component"
		desc:       "TopoLVM CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
