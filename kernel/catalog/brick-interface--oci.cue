@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/oci": {
		path: "kernel/interface/oci"
		slug: "interface--oci"
		kind: "interface"
		reads: []
		writes: []
		desc:        "OCI external image references contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "oci_images"
	}
}
