@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/slackbot": {
		path:       "tenant/library/go/lib/gen/slackbot"
		slug:       "go--lib--gen--slackbot"
		kind:       "component"
		desc:       "slackbot"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
