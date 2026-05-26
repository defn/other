@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/go-cmd": {
		path: "kernel/interface/go-cmd"
		slug: "interface--go-cmd"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Go cobra command contract and templates"
		midas:       true
		stamping:    "generator"
		catalog_key: "go_cmd_bricks"
	}
}
