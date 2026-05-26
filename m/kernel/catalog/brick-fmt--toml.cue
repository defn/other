@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/toml": {
		path: "kernel/fmt/toml"
		slug: "fmt--toml"
		kind: "component"
		reads: []
		writes: []
		desc:       "TOML formatter (taplo)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
