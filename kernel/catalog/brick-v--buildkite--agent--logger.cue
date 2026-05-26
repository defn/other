@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/logger": {
		path:       "v/buildkite--agent/logger"
		slug:       "v--buildkite--agent--logger"
		kind:       "component"
		desc:       "structured logging"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
