@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/agent/integration": {
		path:       "v/buildkite--agent/agent/integration"
		slug:       "v--buildkite--agent--agent--integration"
		kind:       "component"
		desc:       "agent integration tests"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
