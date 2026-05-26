@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/bazel": {
		path: "kernel/fmt/bazel"
		slug: "fmt--bazel"
		kind: "component"
		reads: []
		writes: []
		desc:       "Bazel formatter (buildifier)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
