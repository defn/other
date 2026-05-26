@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/oci": {
		path: "kernel/oci"
		slug: "oci"
		kind: "branch"
		reads: []
		writes: []
		desc: "OCI external image instances"
		composes: [
			"kernel/oci/bazel-remote",
			"kernel/oci/registry",
			"kernel/oci/ubuntu",
		]
	}
}
