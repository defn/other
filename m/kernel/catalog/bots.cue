@experiment(aliasv2,explicitopen,shortcircuit,try)

// Schema constraints only. Bot instances live in
// tenant/<t>/catalog/bots.cue (defn-only today).
package catalog

import "github.com/defn/other/kernel/schema"

slack_bots: [string]:    schema.#SlackBot
discord_bots: [string]:  schema.#DiscordBot
gmail_bots: [string]:    schema.#GmailBot
matrix_bots: [string]:   schema.#MatrixBot
telegram_bots: [string]: schema.#TelegramBot
