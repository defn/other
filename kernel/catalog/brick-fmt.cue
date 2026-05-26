@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/fmt": {
		path: "kernel/fmt"
		slug: "fmt"
		kind: "branch"
		reads: []
		writes: []
		desc: "formatter instances"
		composes: [
			"kernel/fmt/toml",
			"kernel/fmt/json",
			"kernel/fmt/yaml",
			"kernel/fmt/cue",
			"kernel/fmt/dprint",
			"kernel/fmt/go",
			"kernel/fmt/python",
			"kernel/fmt/java",
			"kernel/fmt/clojure",
			"kernel/fmt/typescript",
			"kernel/fmt/bazel",
			"kernel/fmt/markdown",
			"kernel/fmt/packer",
			"kernel/fmt/shell",
			"kernel/fmt/tofu",
		]
	}
}
