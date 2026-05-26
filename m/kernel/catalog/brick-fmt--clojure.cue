@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt/clojure": {
		path: "kernel/fmt/clojure"
		slug: "fmt--clojure"
		kind: "component"
		reads: []
		writes: []
		desc:       "Clojure formatter (cljstyle)"
		implements: "kernel/interface/fmt"
		stamp_type: "gen"
	}
}
