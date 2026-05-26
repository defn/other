@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/discord-bot": {
		path: "kernel/interface/discord-bot"
		slug: "interface--discord-bot"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Discord bot instance contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "discord_bots"
	}
}
