@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/env": {
		path:       "v/buildkite--agent/env"
		slug:       "v--buildkite--agent--env"
		kind:       "component"
		desc:       "environment variable management"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
