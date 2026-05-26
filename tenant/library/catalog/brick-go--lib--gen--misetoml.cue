@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/misetoml": {
		path:       "tenant/library/go/lib/gen/misetoml"
		slug:       "go--lib--gen--misetoml"
		kind:       "component"
		desc:       "misetoml"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
