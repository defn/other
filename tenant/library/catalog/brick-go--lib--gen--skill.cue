@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/skill": {
		path:       "tenant/library/go/lib/gen/skill"
		slug:       "go--lib--gen--skill"
		kind:       "component"
		desc:       "skill"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
