@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/oci/registry": {
		path: "kernel/oci/registry"
		slug: "oci--registry"
		kind: "component"
		reads: []
		writes: []
		desc:       "registry OCI image reference"
		implements: "kernel/interface/oci"
		stamp_type: "gen"
	}
}
