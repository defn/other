@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/shell": {
		path:       "v/buildkite--agent/internal/shell"
		slug:       "v--buildkite--agent--internal--shell"
		kind:       "component"
		desc:       "shell execution"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
