@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/brickpkg": {
		path:       "tenant/library/go/lib/brickpkg"
		slug:       "go--lib--brickpkg"
		kind:       "component"
		desc:       "brickpkg"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
