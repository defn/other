@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: matrixbot generator.
//
// Traceability:
//   Go source:      go/lib/gen/matrixbot/matrixbot.go
//   Reads catalogs: catalog.matrix_bots
//   Template:       interface/matrix-bot/templates.cue
//
// Why these files exist: each Matrix bot brick has BUILD.bazel +
// mise.toml + .gitignore. Matrix access tokens live in a secret
// store, not in the brick, and are not claimed here.
//
// See AIDR-00062.

package contracts

bricks: [string]: {
	path:       string
	implements: string | *""
	...
}

generators: matrixbot: {
	generator: "matrixbot"
	source:    "tenant/library/go/lib/gen/matrixbot"
	reason:    "stamps per-Matrix-bot brick dirs (BUILD.bazel + mise.toml + .gitignore) from catalog.matrix_bots"
	read_from: {
		catalog: ["matrix_bots"]
		paths: ["kernel/interface/matrix-bot/templates.cue"]
	}
	related_aidr: [62]
	paths: [
		for _, b in bricks
		if b.implements == "kernel/interface/matrix-bot"
		for f in ["BUILD.bazel", "mise.toml", ".gitignore"] {"\(b.path)/\(f)"},
	]
}
