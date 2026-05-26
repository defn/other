@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/spec/brickcollision": {
		path:       "tenant/library/go/lib/spec/brickcollision"
		slug:       "go--lib--spec--brickcollision"
		kind:       "component"
		desc:       "brickcollision"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
