@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/app": {
		path: "kernel/interface/app"
		slug: "interface--app"
		kind: "interface"
		reads: []
		writes: []
		desc:        "app definition contract and Bazel macros"
		midas:       true
		stamping:    "macro"
		catalog_key: "apps"
	}
}
