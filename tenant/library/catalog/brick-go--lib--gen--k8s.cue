@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/k8s": {
		path:       "tenant/library/go/lib/gen/k8s"
		slug:       "go--lib--gen--k8s"
		kind:       "component"
		desc:       "k8s"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
