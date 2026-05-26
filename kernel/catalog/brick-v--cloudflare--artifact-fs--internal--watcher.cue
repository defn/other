@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/watcher": {
		path:       "v/cloudflare--artifact-fs/internal/watcher"
		slug:       "v--cloudflare--artifact-fs--internal--watcher"
		kind:       "component"
		desc:       "watcher"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
