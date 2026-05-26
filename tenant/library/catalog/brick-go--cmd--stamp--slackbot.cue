@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/slackbot": {
		path:       "tenant/library/go/cmd/stamp/slackbot"
		slug:       "go--cmd--stamp--slackbot"
		kind:       "component"
		desc:       "slackbot"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
