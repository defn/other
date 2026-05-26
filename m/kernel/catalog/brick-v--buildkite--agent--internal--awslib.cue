@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/awslib": {
		path:       "v/buildkite--agent/internal/awslib"
		slug:       "v--buildkite--agent--internal--awslib"
		kind:       "component"
		desc:       "AWS SDK helpers"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
