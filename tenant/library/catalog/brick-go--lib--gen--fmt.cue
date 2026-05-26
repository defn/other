@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/fmt": {
		path:       "tenant/library/go/lib/gen/fmt"
		slug:       "go--lib--gen--fmt"
		kind:       "component"
		desc:       "fmt"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
