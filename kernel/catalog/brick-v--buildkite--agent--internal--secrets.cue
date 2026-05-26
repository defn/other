@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/secrets": {
		path:       "v/buildkite--agent/internal/secrets"
		slug:       "v--buildkite--agent--internal--secrets"
		kind:       "component"
		desc:       "secret management"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
