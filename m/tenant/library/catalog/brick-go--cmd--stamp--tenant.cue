@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/tenant": {
		path:       "tenant/library/go/cmd/stamp/tenant"
		slug:       "go--cmd--stamp--tenant"
		kind:       "component"
		desc:       "stamp the universal-identity scaffolding for a tenant"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
