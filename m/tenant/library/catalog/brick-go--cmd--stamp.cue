@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp": {
		path:       "tenant/library/go/cmd/stamp"
		slug:       "go--cmd--stamp"
		kind:       "component"
		desc:       "stamp"
		implements: "kernel/interface/go-cmd-parent"
		reads: []
		writes: []
		stamp_type: "go-cmd-parent"
	}
}
