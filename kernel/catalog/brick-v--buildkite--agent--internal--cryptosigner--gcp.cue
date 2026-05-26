@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/cryptosigner/gcp": {
		path:       "v/buildkite--agent/internal/cryptosigner/gcp"
		slug:       "v--buildkite--agent--internal--cryptosigner--gcp"
		kind:       "component"
		desc:       "GCP KMS signer"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
