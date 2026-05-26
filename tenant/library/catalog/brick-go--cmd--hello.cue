@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/hello": {
		path:       "tenant/library/go/cmd/hello"
		slug:       "go--cmd--hello"
		kind:       "component"
		desc:       "hello"
		implements: "kernel/interface/go-cmd-cue"
		reads: []
		writes: []
		stamp_type: "go-cmd-cue"
	}
}
