@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/cmd/root": {
		path: "tenant/library/go/cmd/root"
		slug: "go--cmd--root"
		kind: "component"
		reads: []
		writes: []
		desc: "CLI root command"
	}
}
