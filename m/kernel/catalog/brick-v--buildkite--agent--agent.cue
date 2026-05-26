@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/agent": {
		path:       "v/buildkite--agent/agent"
		slug:       "v--buildkite--agent--agent"
		kind:       "component"
		desc:       "build agent worker pool and job runner"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
