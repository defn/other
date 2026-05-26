@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/gmail-bot": {
		path: "kernel/interface/gmail-bot"
		slug: "interface--gmail-bot"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Gmail bot instance contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "gmail_bots"
	}
}
