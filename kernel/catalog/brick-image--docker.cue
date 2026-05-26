@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/image/docker": {
		path: "kernel/image/docker"
		slug: "image--docker"
		kind: "branch"
		reads: []
		writes: []
		desc: "Docker container images"
		composes: [
			"kernel/image/docker/base",
			"kernel/image/docker/bazel-remote",
			"kernel/image/docker/edge",
			"kernel/image/docker/postgres",
			"kernel/image/docker/redis",
			"kernel/image/docker/registry",
		]
	}
}
