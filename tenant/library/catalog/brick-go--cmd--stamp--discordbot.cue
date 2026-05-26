@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/discordbot": {
		path:       "tenant/library/go/cmd/stamp/discordbot"
		slug:       "go--cmd--stamp--discordbot"
		kind:       "component"
		desc:       "discordbot"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
