@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/process": {
		path:       "v/buildkite--agent/process"
		slug:       "v--buildkite--agent--process"
		kind:       "component"
		desc:       "process execution and PTY"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
