@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/spec/brickreads": {
		path:       "tenant/library/go/lib/spec/brickreads"
		slug:       "go--lib--spec--brickreads"
		kind:       "component"
		desc:       "brickreads"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
