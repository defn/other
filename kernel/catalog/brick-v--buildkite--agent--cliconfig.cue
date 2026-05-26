@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/cliconfig": {
		path:       "v/buildkite--agent/cliconfig"
		slug:       "v--buildkite--agent--cliconfig"
		kind:       "component"
		desc:       "CLI config file loader"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
