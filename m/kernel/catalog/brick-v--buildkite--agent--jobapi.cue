@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/jobapi": {
		path:       "v/buildkite--agent/jobapi"
		slug:       "v--buildkite--agent--jobapi"
		kind:       "component"
		desc:       "local job HTTP API"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
