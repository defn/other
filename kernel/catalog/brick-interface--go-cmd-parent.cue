@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/go-cmd-parent": {
		path: "kernel/interface/go-cmd-parent"
		slug: "interface--go-cmd-parent"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Go parent command grouping child subcommands"
		midas:       true
		stamping:    "generator"
		catalog_key: "go_cmd_parent_bricks"
	}
}
