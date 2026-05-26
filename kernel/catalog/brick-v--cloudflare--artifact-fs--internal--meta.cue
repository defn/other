@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/meta": {
		path:       "v/cloudflare--artifact-fs/internal/meta"
		slug:       "v--cloudflare--artifact-fs--internal--meta"
		kind:       "component"
		desc:       "meta"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
