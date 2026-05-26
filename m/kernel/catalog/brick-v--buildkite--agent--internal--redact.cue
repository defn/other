@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/redact": {
		path:       "v/buildkite--agent/internal/redact"
		slug:       "v--buildkite--agent--internal--redact"
		kind:       "component"
		desc:       "log redaction"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
