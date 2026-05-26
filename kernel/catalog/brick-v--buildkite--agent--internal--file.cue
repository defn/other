@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/file": {
		path:       "v/buildkite--agent/internal/file"
		slug:       "v--buildkite--agent--internal--file"
		kind:       "component"
		desc:       "file state utilities"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
