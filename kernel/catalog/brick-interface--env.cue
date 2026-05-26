@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/env": {
		path: "kernel/interface/env"
		slug: "interface--env"
		kind: "interface"
		reads: []
		writes: []
		desc:        "environment definition contract and templates"
		midas:       true
		stamping:    "generator"
		catalog_key: "environments"
	}
}
