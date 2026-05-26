@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/discordbot": {
		path:       "tenant/library/go/lib/gen/discordbot"
		slug:       "go--lib--gen--discordbot"
		kind:       "component"
		desc:       "discordbot"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
