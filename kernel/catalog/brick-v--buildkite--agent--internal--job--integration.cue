@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/job/integration": {
		path:       "v/buildkite--agent/internal/job/integration"
		slug:       "v--buildkite--agent--internal--job--integration"
		kind:       "component"
		desc:       "job integration tests"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
