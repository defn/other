@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: discordbot generator.
//
// Traceability:
//   Go source:      go/lib/gen/discordbot/discordbot.go
//   Reads catalogs: catalog.discord_bots
//   Template:       interface/discord-bot/templates.cue
//
// Why these files exist: each Discord bot brick has BUILD.bazel +
// mise.toml + .gitignore. Unlike Slack bots, Discord doesn't use a
// manifest file (gateway intents are registered via API at runtime),
// so the generator writes only three files per bot.
//
// See AIDR-00062.

package contracts

bricks: [string]: {
	path:       string
	implements: string | *""
	...
}

generators: discordbot: {
	generator: "discordbot"
	source:    "tenant/library/go/lib/gen/discordbot"
	reason:    "stamps per-Discord-bot brick dirs (BUILD.bazel + mise.toml + .gitignore) from catalog.discord_bots"
	read_from: {
		catalog: ["discord_bots"]
		paths: ["kernel/interface/discord-bot/templates.cue"]
	}
	related_aidr: [62]
	paths: [
		for _, b in bricks
		if b.implements == "kernel/interface/discord-bot"
		for f in ["BUILD.bazel", "mise.toml", ".gitignore"] {"\(b.path)/\(f)"},
	]
}
