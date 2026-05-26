@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/k8s": {
		path: "kernel/interface/k8s"
		slug: "interface--k8s"
		kind: "interface"
		reads: []
		writes: []
		desc:        "k8s platform definition contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "k8s_platforms"
	}
}
