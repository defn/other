@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/matrix-bot": {
		path: "kernel/interface/matrix-bot"
		slug: "interface--matrix-bot"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Matrix bot instance contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "matrix_bots"
	}
}
