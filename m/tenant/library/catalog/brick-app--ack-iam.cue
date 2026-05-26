@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/ack-iam": {
		path:       "tenant/library/app/ack-iam"
		slug:       "app--ack-iam"
		kind:       "component"
		desc:       "ACK IAM controller"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
