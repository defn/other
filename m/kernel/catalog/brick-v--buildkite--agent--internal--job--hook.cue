@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/job/hook": {
		path:       "v/buildkite--agent/internal/job/hook"
		slug:       "v--buildkite--agent--internal--job--hook"
		kind:       "component"
		desc:       "hook execution"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
