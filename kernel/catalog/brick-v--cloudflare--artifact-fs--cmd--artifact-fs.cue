@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/cmd/artifact-fs": {
		path:       "v/cloudflare--artifact-fs/cmd/artifact-fs"
		slug:       "v--cloudflare--artifact-fs--cmd--artifact-fs"
		kind:       "component"
		desc:       "artifact-fs"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
