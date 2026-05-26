@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/clicommand": {
		path:       "v/buildkite--agent/clicommand"
		slug:       "v--buildkite--agent--clicommand"
		kind:       "component"
		desc:       "CLI command definitions"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
