@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/tracetools": {
		path:       "v/buildkite--agent/tracetools"
		slug:       "v--buildkite--agent--tracetools"
		kind:       "component"
		desc:       "OpenTelemetry tracing"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
