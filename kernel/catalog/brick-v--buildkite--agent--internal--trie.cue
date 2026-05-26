@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/trie": {
		path:       "v/buildkite--agent/internal/trie"
		slug:       "v--buildkite--agent--internal--trie"
		kind:       "component"
		desc:       "trie data structure"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
