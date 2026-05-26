@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/slack-bot": {
		path: "kernel/interface/slack-bot"
		slug: "interface--slack-bot"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Slack bot instance contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "slack_bots"
	}
}
