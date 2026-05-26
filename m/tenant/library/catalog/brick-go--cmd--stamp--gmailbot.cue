@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/gmailbot": {
		path:       "tenant/library/go/cmd/stamp/gmailbot"
		slug:       "go--cmd--stamp--gmailbot"
		kind:       "component"
		desc:       "gmailbot"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
