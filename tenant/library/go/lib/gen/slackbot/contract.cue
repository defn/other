@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: slackbot generator.
//
// Traceability:
//   Go source:      go/lib/gen/slackbot/slackbot.go
//   Reads catalogs: catalog.slack_bots
//   Template:       interface/slack-bot/templates.cue
//
// Why these files exist: each Slack bot is a single brick directory
// holding a manifest.json (Slack app manifest), a BUILD.bazel (Bazel
// wiring), a mise.toml (env vars for local runs), and a .gitignore
// (scope hygiene). The generator stamps all four from a compact
// catalog entry per bot.
//
// Other bot families (discord/gmail/matrix/telegram) follow the same
// pattern minus manifest.json. Each has its own contract next to its
// Go source. See AIDR-00062.

package contracts

// Bind catalog.bricks from the lattice JSON. We default `implements`
// to "" so the for-comprehension below can reference it without
// tripping CUE's "cannot reference optional field" rule.
bricks: [string]: {
	path:       string
	implements: string | *""
	...
}

generators: slackbot: {
	generator: "slackbot"
	source:    "tenant/library/go/lib/gen/slackbot"
	reason:    "stamps per-Slack-bot brick dirs (BUILD.bazel + manifest.json + mise.toml + .gitignore) from catalog.slack_bots"
	read_from: {
		catalog: ["slack_bots"]
		paths: ["kernel/interface/slack-bot/templates.cue"]
	}
	related_aidr: [62]
	// Fixed file set per slack-bot brick; iterate catalog.bricks
	// filtered by implements to get the roster.
	paths: [
		for _, b in bricks
		if b.implements == "kernel/interface/slack-bot"
		for f in ["BUILD.bazel", "manifest.json", "mise.toml", ".gitignore"] {"\(b.path)/\(f)"},
	]
}
