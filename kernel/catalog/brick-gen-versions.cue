@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/gen-versions": {
		path: "kernel/gen-versions"
		slug: "gen-versions"
		kind: "component"
		reads: []
		writes: []
		desc: "per-tool Bazel version constants"
	}
}
