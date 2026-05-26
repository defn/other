@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/registry": {
		path:       "v/cloudflare--artifact-fs/internal/registry"
		slug:       "v--cloudflare--artifact-fs--internal--registry"
		kind:       "component"
		desc:       "registry"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
