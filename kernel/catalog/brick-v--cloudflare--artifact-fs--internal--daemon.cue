@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/daemon": {
		path:       "v/cloudflare--artifact-fs/internal/daemon"
		slug:       "v--cloudflare--artifact-fs--internal--daemon"
		kind:       "component"
		desc:       "daemon"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
