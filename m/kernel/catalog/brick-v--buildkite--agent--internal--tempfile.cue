@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/tempfile": {
		path:       "v/buildkite--agent/internal/tempfile"
		slug:       "v--buildkite--agent--internal--tempfile"
		kind:       "component"
		desc:       "temp file management"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
