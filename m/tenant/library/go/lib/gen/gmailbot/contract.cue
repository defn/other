@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: gmailbot generator.
//
// Traceability:
//   Go source:      go/lib/gen/gmailbot/gmailbot.go
//   Reads catalogs: catalog.gmail_bots
//   Template:       interface/gmail-bot/templates.cue
//
// Why these files exist: each Gmail bot brick has BUILD.bazel +
// mise.toml + .gitignore. Credentials and OAuth state live outside
// the brick (see root/.config/gmail/ when it lands under scope) and
// are not claimed here.
//
// See AIDR-00062.

package contracts

bricks: [string]: {
	path:       string
	implements: string | *""
	...
}

generators: gmailbot: {
	generator: "gmailbot"
	source:    "tenant/library/go/lib/gen/gmailbot"
	reason:    "stamps per-Gmail-bot brick dirs (BUILD.bazel + mise.toml + .gitignore) from catalog.gmail_bots"
	read_from: {
		catalog: ["gmail_bots"]
		paths: ["kernel/interface/gmail-bot/templates.cue"]
	}
	related_aidr: [62]
	paths: [
		for _, b in bricks
		if b.implements == "kernel/interface/gmail-bot"
		for f in ["BUILD.bazel", "mise.toml", ".gitignore"] {"\(b.path)/\(f)"},
	]
}
