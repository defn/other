@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/kyverno": {
		path:       "tenant/library/app/kyverno"
		slug:       "app--kyverno"
		kind:       "component"
		desc:       "Policy engine and guardrails"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
