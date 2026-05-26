@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/api/proto/gen": {
		path:       "v/buildkite--agent/api/proto/gen"
		slug:       "v--buildkite--agent--api--proto--gen"
		kind:       "component"
		desc:       "protobuf generated types"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
