@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/kubernetes": {
		path:       "v/buildkite--agent/kubernetes"
		slug:       "v--buildkite--agent--kubernetes"
		kind:       "component"
		desc:       "kubernetes runner"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
