@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/oci/bazel-remote": {
		path: "kernel/oci/bazel-remote"
		slug: "oci--bazel-remote"
		kind: "component"
		reads: []
		writes: []
		desc:       "bazel-remote OCI image reference"
		implements: "kernel/interface/oci"
		stamp_type: "gen"
	}
}
