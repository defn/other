@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"root/.aws": {
		path: "root/.aws"
		slug: "root--.aws"
		kind: "component"
		reads: []
		writes: []
		desc: "AWS SSO config (symlinked from ~/.aws)"
	}
}
