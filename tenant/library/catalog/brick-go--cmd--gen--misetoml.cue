@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/misetoml": {
		path:       "tenant/library/go/cmd/gen/misetoml"
		slug:       "go--cmd--gen--misetoml"
		kind:       "component"
		desc:       "misetoml"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
