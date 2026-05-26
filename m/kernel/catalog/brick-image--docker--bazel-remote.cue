@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/docker/bazel-remote": {
		path: "kernel/image/docker/bazel-remote"
		slug: "image--docker--bazel-remote"
		kind: "component"
		reads: []
		writes: []
		desc:       "bazel-remote container image"
		implements: "kernel/interface/image"
		stamp_type: "gen"
	}
}
