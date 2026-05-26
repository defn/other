@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/hydrator": {
		path:       "v/cloudflare--artifact-fs/internal/hydrator"
		slug:       "v--cloudflare--artifact-fs--internal--hydrator"
		kind:       "component"
		desc:       "hydrator"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
