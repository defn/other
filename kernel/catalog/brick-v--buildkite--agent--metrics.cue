@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/metrics": {
		path:       "v/buildkite--agent/metrics"
		slug:       "v--buildkite--agent--metrics"
		kind:       "component"
		desc:       "metrics collection"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
