@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/gen/discordbot": {
		path:       "tenant/library/go/cmd/gen/discordbot"
		slug:       "go--cmd--gen--discordbot"
		kind:       "component"
		desc:       "discordbot"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/gen"
		stamp_type: "go-cmd"
	}
}
