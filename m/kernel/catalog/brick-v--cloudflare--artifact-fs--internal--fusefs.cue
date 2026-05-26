@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/fusefs": {
		path:       "v/cloudflare--artifact-fs/internal/fusefs"
		slug:       "v--cloudflare--artifact-fs--internal--fusefs"
		kind:       "component"
		desc:       "fusefs"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
