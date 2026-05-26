@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/ptr": {
		path:       "v/buildkite--agent/internal/ptr"
		slug:       "v--buildkite--agent--internal--ptr"
		kind:       "component"
		desc:       "pointer helpers"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
