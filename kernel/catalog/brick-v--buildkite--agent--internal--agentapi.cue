@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/agentapi": {
		path:       "v/buildkite--agent/internal/agentapi"
		slug:       "v--buildkite--agent--internal--agentapi"
		kind:       "component"
		desc:       "local agent API server"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
