@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/fmt": {
		path: "kernel/interface/fmt"
		slug: "interface--fmt"
		kind: "interface"
		reads: []
		writes: []
		desc:        "formatter contract and schema"
		midas:       true
		stamping:    "generator"
		catalog_key: "formatters"
	}
}
