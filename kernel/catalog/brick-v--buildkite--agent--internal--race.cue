@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/race": {
		path:       "v/buildkite--agent/internal/race"
		slug:       "v--buildkite--agent--internal--race"
		kind:       "component"
		desc:       "race detector helpers"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
