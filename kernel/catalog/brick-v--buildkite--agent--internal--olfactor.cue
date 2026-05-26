@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/olfactor": {
		path:       "v/buildkite--agent/internal/olfactor"
		slug:       "v--buildkite--agent--internal--olfactor"
		kind:       "component"
		desc:       "secret sniffer in output"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
