@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/go-lib": {
		path: "kernel/interface/go-lib"
		slug: "interface--go-lib"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Go library package contract and templates"
		midas:       true
		stamping:    "generator"
		catalog_key: "go_lib_bricks"
	}
}
