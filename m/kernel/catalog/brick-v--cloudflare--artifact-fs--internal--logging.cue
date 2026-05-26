@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/logging": {
		path:       "v/cloudflare--artifact-fs/internal/logging"
		slug:       "v--cloudflare--artifact-fs--internal--logging"
		kind:       "component"
		desc:       "logging"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
