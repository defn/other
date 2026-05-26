@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/status": {
		path:       "v/buildkite--agent/status"
		slug:       "v--buildkite--agent--status"
		kind:       "component"
		desc:       "agent status"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
