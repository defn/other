@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/pipeline": {
		path:       "tenant/library/go/cmd/pipeline"
		slug:       "go--cmd--pipeline"
		kind:       "component"
		desc:       "pipeline"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		stamp_type: "go-cmd"
	}
}
