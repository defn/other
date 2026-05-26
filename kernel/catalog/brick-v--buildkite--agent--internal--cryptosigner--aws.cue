@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"v/buildkite--agent/internal/cryptosigner/aws": {
		path:       "v/buildkite--agent/internal/cryptosigner/aws"
		slug:       "v--buildkite--agent--internal--cryptosigner--aws"
		kind:       "component"
		desc:       "AWS KMS signer"
		implements: "kernel/interface/go-lib"
		reads: []
		writes: []
		stamp_type: "go-lib"
	}
}
