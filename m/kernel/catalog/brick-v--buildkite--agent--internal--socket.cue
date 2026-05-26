@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/socket": {
		path:       "v/buildkite--agent/internal/socket"
		slug:       "v--buildkite--agent--internal--socket"
		kind:       "component"
		desc:       "unix socket utilities"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
