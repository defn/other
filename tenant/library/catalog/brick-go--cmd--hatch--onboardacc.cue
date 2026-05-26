@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/hatch/onboardacc": {
		path:       "tenant/library/go/cmd/hatch/onboardacc"
		slug:       "go--cmd--hatch--onboardacc"
		kind:       "component"
		desc:       "onboard new AWS account: bootstrap role + verify"
		implements: "kernel/interface/go-cmd"
		reads: []
		writes: []
		parent:     "tenant/library/go/cmd/hatch"
		stamp_type: "go-cmd"
	}
}
