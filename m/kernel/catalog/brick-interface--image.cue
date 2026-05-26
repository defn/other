@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/image": {
		path: "kernel/interface/image"
		slug: "interface--image"
		kind: "interface"
		reads: []
		writes: []
		desc:        "container image build contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "container_images"
	}
}
