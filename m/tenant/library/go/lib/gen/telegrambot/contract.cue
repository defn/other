@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: telegrambot generator.
//
// Traceability:
//   Go source:      go/lib/gen/telegrambot/telegrambot.go
//   Reads catalogs: catalog.telegram_bots
//   Template:       interface/telegram-bot/templates.cue
//
// Why these files exist: each Telegram bot brick has BUILD.bazel +
// mise.toml + .gitignore. Bot tokens live in a secret store and are
// not claimed here.
//
// See AIDR-00062.

package contracts

bricks: [string]: {
	path:       string
	implements: string | *""
	...
}

generators: telegrambot: {
	generator: "telegrambot"
	source:    "tenant/library/go/lib/gen/telegrambot"
	reason:    "stamps per-Telegram-bot brick dirs (BUILD.bazel + mise.toml + .gitignore) from catalog.telegram_bots"
	read_from: {
		catalog: ["telegram_bots"]
		paths: ["kernel/interface/telegram-bot/templates.cue"]
	}
	related_aidr: [62]
	paths: [
		for _, b in bricks
		if b.implements == "kernel/interface/telegram-bot"
		for f in ["BUILD.bazel", "mise.toml", ".gitignore"] {"\(b.path)/\(f)"},
	]
}
