@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/buildbuddy": {
		path:       "tenant/library/app/buildbuddy"
		slug:       "app--buildbuddy"
		kind:       "component"
		desc:       "BuildBuddy Bazel cache and events server"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
