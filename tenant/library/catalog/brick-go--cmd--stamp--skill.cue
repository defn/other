@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/stamp/skill": {
		path:       "tenant/library/go/cmd/stamp/skill"
		slug:       "go--cmd--stamp--skill"
		kind:       "component"
		desc:       "skill"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/stamp"
		stamp_type: "go-cmd"
	}
}
