@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/build": {
		path:       "tenant/library/go/cmd/build"
		slug:       "go--cmd--build"
		kind:       "component"
		desc:       "air-gapped build agent"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		stamp_type: "go-cmd"
	}
}
