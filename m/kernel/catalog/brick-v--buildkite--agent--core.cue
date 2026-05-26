@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/core": {
		path:       "v/buildkite--agent/core"
		slug:       "v--buildkite--agent--core"
		kind:       "component"
		desc:       "programmatic job control"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
