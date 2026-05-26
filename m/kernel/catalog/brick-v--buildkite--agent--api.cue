@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/api": {
		path:       "v/buildkite--agent/api"
		slug:       "v--buildkite--agent--api"
		kind:       "component"
		desc:       "build API client"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
