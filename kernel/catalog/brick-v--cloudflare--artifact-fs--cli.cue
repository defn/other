@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/cloudflare--artifact-fs/cli": {
		path:       "v/cloudflare--artifact-fs/cli"
		slug:       "v--cloudflare--artifact-fs--cli"
		kind:       "component"
		desc:       "cli re-export (avoids Go internal-package rule for defn afs)"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
