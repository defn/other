@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/module": {
		path: "kernel/module"
		slug: "module"
		kind: "branch"
		reads: []
		writes: []
		desc: "tofu module interfaces"
		composes: [
			"kernel/module/aws-org",
			"kernel/module/aws-account",
		]
	}
}
