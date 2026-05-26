@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/check": {
		path:       "tenant/library/go/cmd/check"
		slug:       "go--cmd--check"
		kind:       "component"
		desc:       "check"
		implements: "kernel/interface/go-cmd-parent"
		reads: []
		writes: []
		stamp_type: "go-cmd-parent"
	}
}
