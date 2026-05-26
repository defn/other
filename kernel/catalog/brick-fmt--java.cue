@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/java": {
		path: "kernel/fmt/java"
		slug: "fmt--java"
		kind: "component"
		reads: []
		writes: []
		desc:       "Java formatter (google-java-format)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
