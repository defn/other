@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/overlay": {
		path:       "v/cloudflare--artifact-fs/internal/overlay"
		slug:       "v--cloudflare--artifact-fs--internal--overlay"
		kind:       "component"
		desc:       "overlay"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
