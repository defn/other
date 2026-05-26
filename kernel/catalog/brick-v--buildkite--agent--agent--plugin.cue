@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/agent/plugin": {
		path:       "v/buildkite--agent/agent/plugin"
		slug:       "v--buildkite--agent--agent--plugin"
		kind:       "component"
		desc:       "buildkite plugin parser"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
