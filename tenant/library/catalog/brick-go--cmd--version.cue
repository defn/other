@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/version": {
		path:       "tenant/library/go/cmd/version"
		slug:       "go--cmd--version"
		kind:       "component"
		desc:       "version"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		stamp_type: "go-cmd"
	}
}
