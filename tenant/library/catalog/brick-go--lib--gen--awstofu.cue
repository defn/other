@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen/awstofu": {
		path:       "tenant/library/go/lib/gen/awstofu"
		slug:       "go--lib--gen--awstofu"
		kind:       "component"
		desc:       "awstofu"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
