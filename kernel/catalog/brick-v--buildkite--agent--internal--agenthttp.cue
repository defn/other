@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/agenthttp": {
		path:       "v/buildkite--agent/internal/agenthttp"
		slug:       "v--buildkite--agent--internal--agenthttp"
		kind:       "component"
		desc:       "HTTP client helpers"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
