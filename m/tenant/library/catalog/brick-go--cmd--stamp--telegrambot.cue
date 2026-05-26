@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/telegrambot": {
		path:       "tenant/library/go/cmd/stamp/telegrambot"
		slug:       "go--cmd--stamp--telegrambot"
		kind:       "component"
		desc:       "telegrambot"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
