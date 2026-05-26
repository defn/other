@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/osutil": {
		path:       "v/buildkite--agent/internal/osutil"
		slug:       "v--buildkite--agent--internal--osutil"
		kind:       "component"
		desc:       "OS utility functions"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
