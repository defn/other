@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/linkerd-control-plane": {
		path:       "tenant/library/app/linkerd-control-plane"
		slug:       "app--linkerd-control-plane"
		kind:       "component"
		desc:       "Linkerd service mesh control plane"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
