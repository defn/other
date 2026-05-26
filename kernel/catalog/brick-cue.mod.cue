@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"cue.mod": {
		path: "cue.mod"
		slug: "cue.mod"
		kind: "interface"
		reads: []
		desc: "CUE module definition"
	}
}
