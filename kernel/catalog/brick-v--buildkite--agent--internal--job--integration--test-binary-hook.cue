@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/job/integration/test-binary-hook": {
		path:       "v/buildkite--agent/internal/job/integration/test-binary-hook"
		slug:       "v--buildkite--agent--internal--job--integration--test-binary-hook"
		kind:       "component"
		desc:       "test binary hook helper"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
