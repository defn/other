@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/cache": {
		path:       "v/buildkite--agent/internal/cache"
		slug:       "v--buildkite--agent--internal--cache"
		kind:       "component"
		desc:       "build cache"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
