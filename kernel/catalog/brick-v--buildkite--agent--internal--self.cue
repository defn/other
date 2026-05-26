@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/self": {
		path:       "v/buildkite--agent/internal/self"
		slug:       "v--buildkite--agent--internal--self"
		kind:       "component"
		desc:       "binary path resolution"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
