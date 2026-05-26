@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/validate": {
		path:       "tenant/library/go/lib/gen/validate"
		slug:       "go--lib--gen--validate"
		kind:       "component"
		desc:       "validate"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
