@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/test/fixtures/hook": {
		path:       "v/buildkite--agent/test/fixtures/hook"
		slug:       "v--buildkite--agent--test--fixtures--hook"
		kind:       "component"
		desc:       "test hook fixtures"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
