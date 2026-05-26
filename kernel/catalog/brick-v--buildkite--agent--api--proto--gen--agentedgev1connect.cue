@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/api/proto/gen/agentedgev1connect": {
		path:       "v/buildkite--agent/api/proto/gen/agentedgev1connect"
		slug:       "v--buildkite--agent--api--proto--gen--agentedgev1connect"
		kind:       "component"
		desc:       "connect-go service"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
