@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/stdin": {
		path:       "v/buildkite--agent/internal/stdin"
		slug:       "v--buildkite--agent--internal--stdin"
		kind:       "component"
		desc:       "stdin helpers"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
