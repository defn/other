@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/mime": {
		path:       "v/buildkite--agent/internal/mime"
		slug:       "v--buildkite--agent--internal--mime"
		kind:       "component"
		desc:       "MIME type detection"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
