@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/helmapp": {
		path:       "tenant/library/go/cmd/stamp/helmapp"
		slug:       "go--cmd--stamp--helmapp"
		kind:       "component"
		desc:       "stamp a Helm chart app"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
