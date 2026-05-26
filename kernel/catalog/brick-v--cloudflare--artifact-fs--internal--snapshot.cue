@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/snapshot": {
		path:       "v/cloudflare--artifact-fs/internal/snapshot"
		slug:       "v--cloudflare--artifact-fs--internal--snapshot"
		kind:       "component"
		desc:       "snapshot"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
