@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/ack-iam-crds": {
		path:       "tenant/library/app/ack-iam-crds"
		slug:       "app--ack-iam-crds"
		kind:       "component"
		desc:       "ACK IAM controller CRDs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
