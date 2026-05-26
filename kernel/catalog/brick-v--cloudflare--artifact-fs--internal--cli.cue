@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/cli": {
		path:       "v/cloudflare--artifact-fs/internal/cli"
		slug:       "v--cloudflare--artifact-fs--internal--cli"
		kind:       "component"
		desc:       "cli"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
