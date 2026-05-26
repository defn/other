@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/go-cmd-cue": {
		path: "kernel/interface/go-cmd-cue"
		slug: "interface--go-cmd-cue"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Go CUE command contract with schema embedding"
		midas:       true
		stamping:    "generator"
		catalog_key: "go_cmd_cue_bricks"
	}
}
