@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/telegram-bot": {
		path: "kernel/interface/telegram-bot"
		slug: "interface--telegram-bot"
		kind: "interface"
		reads: []
		writes: []
		desc:        "Telegram bot instance contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "telegram_bots"
	}
}
