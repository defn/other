@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/job": {
		path:       "v/buildkite--agent/internal/job"
		slug:       "v--buildkite--agent--internal--job"
		kind:       "component"
		desc:       "job executor"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
