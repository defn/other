@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/k3d": {
		path: "kernel/interface/k3d"
		slug: "interface--k3d"
		kind: "interface"
		reads: []
		writes: []
		desc:        "k3d cluster macros, templates, and catalog re-export"
		midas:       true
		stamping:    "macro"
		catalog_key: "k3d_clusters"
	}
}
