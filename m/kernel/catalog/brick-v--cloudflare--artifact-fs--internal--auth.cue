@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/auth": {
		path:       "v/cloudflare--artifact-fs/internal/auth"
		slug:       "v--cloudflare--artifact-fs--internal--auth"
		kind:       "component"
		desc:       "auth"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
