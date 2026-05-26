@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/gitstore": {
		path:       "v/cloudflare--artifact-fs/internal/gitstore"
		slug:       "v--cloudflare--artifact-fs--internal--gitstore"
		kind:       "component"
		desc:       "gitstore"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
