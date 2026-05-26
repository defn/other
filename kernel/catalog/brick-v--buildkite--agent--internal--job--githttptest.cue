@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/job/githttptest": {
		path:       "v/buildkite--agent/internal/job/githttptest"
		slug:       "v--buildkite--agent--internal--job--githttptest"
		kind:       "component"
		desc:       "git HTTP test server"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
