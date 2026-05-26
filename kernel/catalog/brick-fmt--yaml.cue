@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/yaml": {
		path: "kernel/fmt/yaml"
		slug: "fmt--yaml"
		kind: "component"
		reads: []
		writes: []
		desc:       "YAML formatter (yq)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
