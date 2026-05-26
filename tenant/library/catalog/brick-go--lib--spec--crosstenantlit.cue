@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/spec/crosstenantlit": {
		path:       "tenant/library/go/lib/spec/crosstenantlit"
		slug:       "go--lib--spec--crosstenantlit"
		kind:       "component"
		desc:       "crosstenantlit"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
