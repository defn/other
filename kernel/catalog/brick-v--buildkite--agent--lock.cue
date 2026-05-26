@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/lock": {
		path:       "v/buildkite--agent/lock"
		slug:       "v--buildkite--agent--lock"
		kind:       "component"
		desc:       "distributed locking"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
