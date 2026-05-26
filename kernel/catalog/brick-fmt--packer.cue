@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/packer": {
		path: "kernel/fmt/packer"
		slug: "fmt--packer"
		kind: "component"
		reads: []
		writes: []
		desc:       "Packer HCL formatter (packer fmt)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
