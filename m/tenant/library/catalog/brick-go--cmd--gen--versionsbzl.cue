@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/versionsbzl": {
		path:       "tenant/library/go/cmd/gen/versionsbzl"
		slug:       "go--cmd--gen--versionsbzl"
		kind:       "component"
		desc:       "versionsbzl"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
