@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/internal/model": {
		path:       "v/cloudflare--artifact-fs/internal/model"
		slug:       "v--cloudflare--artifact-fs--internal--model"
		kind:       "component"
		desc:       "model"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
