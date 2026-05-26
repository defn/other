@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: gocmdparent generator.
//
// Traceability:
//   Go source:      go/lib/gen/gocmdparent/gocmdparent.go
//   Reads catalog:  catalog.go_cmd_parent_bricks (implements=
//                   interface/go-cmd-parent), AND child entries
//                   from go_cmd_bricks with a `parent` field set.
//   Templates:      interface/go-cmd-parent/templates.cue (parents)
//                   interface/go-cmd/templates.cue           (children)
//
// Why these files exist: parent commands (bot, gen, hatch, infra,
// stamp) aggregate child subcommands under one cobra command tree.
// The parent writes BUILD.bazel + command.go holding fx wiring that
// imports every child's Module. The children are still go-cmd
// bricks, but because they have a `parent` field set, gocmd skips
// them and gocmdparent handles both ends of the relationship -- one
// generator writes both to avoid split-brain wiring.
//
// Children read their parent's hand-written service.go (if present)
// to detect whether the parent wants a services hook -- the parent's
// gocmdparent.go uses os.Stat to pass has_service into the template
// (gocmdparent.go:148). That's a concrete example of a generator
// *reading* a hand-written file to decide what it writes, which is
// why service.go is manually listed in spec/manual-files.cue.
//
// The path list below is expanded from _parents + _children via a
// CUE list comprehension. To add a new parent or child:
//   1. Add it to _parents (just the subcommand name) or _children
//      (parent name -> [...child names]).
//   2. Run `mise run check` -- vet either passes immediately or tells
//      you which paths are missing/orphaned.
//
// See AIDR-00062.

package contracts

import "list"

// Iterate catalog.bricks for go-cmd-parent bricks (parents) and for
// go-cmd bricks whose `parent` field points at a parent (children).
// Defaults on optional fields dodge CUE's "cannot reference optional
// field" rule inside comprehensions.
bricks: [string]: {
	path:       string
	stamp_type: string | *""
	parent:     string | *""
	...
}

_gocmdparent: {
	// Parent subcommand names under go/cmd/<name>/.
	parents: [
		"bot",
		"gen",
		"hatch",
		"infra",
		"stamp",
	]

	// Child subcommand names grouped by parent.
	children: {
		bot: [
			"create",
			"install",
			"last",
			"run",
			"update",
		]
		gen: [
			"app",
			"cuetree",
			"discordbot",
			"env",
			"fmt",
			"gmailbot",
			"gocmd",
			"gocmdcue",
			"gocmdparent",
			"golib",
			"image",
			"infra",
			"k3d",
			"k8s",
			"matrixbot",
			"misetoml",
			"modulebazel",
			"oci",
			"seed",
			"slackbot",
			"speclattice",
			"telegrambot",
			"versionsbzl",
		]
		hatch: [
			"bzlmodupgrade",
			"goupgrade",
			"helmupgrade",
			"miseupgrade",
			"onboardacc",
		]
		infra: [
			"approve",
			"operator",
			"status",
		]
		stamp: [
			"discordbot",
			"gmailbot",
			"gocmd",
			"gocmdcue",
			"gocmdparent",
			"golib",
			"helmapp",
			"matrixbot",
			"midas",
			"slackbot",
			"telegrambot",
		]
	}

	_filenames: ["BUILD.bazel", "command.go"]
}

// Catalog-driven parent + child paths via bricks filtered by
// stamp_type. Parents: stamp_type == "go-cmd-parent". Children:
// stamp_type == "go-cmd" AND parent != "". The static `parents` and
// `children` blocks above are kept for documentation (they record the
// intended subcommand tree in a human-readable form) but are no
// longer load-bearing for the claim list.
_gocmdparentPaths: [
	for _, b in bricks
	if b.stamp_type == "go-cmd-parent"
	for f in _gocmdparent._filenames {"\(b.path)/\(f)"},
]

_gocmdchildPaths: [
	for _, b in bricks
	if b.stamp_type == "go-cmd" if b.parent != ""
	for f in _gocmdparent._filenames {"\(b.path)/\(f)"},
]

generators: gocmdparent: {
	generator: "gocmdparent"
	source:    "tenant/library/go/lib/gen/gocmdparent"
	reason:    "stamps BUILD.bazel + command.go for each go-cmd-parent brick AND all of its children (children are go-cmd bricks with parent field set)"
	read_from: {
		catalog: ["bricks"]
		paths: [
			"kernel/interface/go-cmd-parent/templates.cue",
			"kernel/interface/go-cmd/templates.cue",
		]
	}
	related_aidr: [62]
	paths: list.Concat([
		_gocmdparentPaths,
		_gocmdchildPaths,
		// In-brick hand-authored files (service.go, deps.cue, ...) across
		// every parent and child; map populated by gocmdparent in the
		// generated inputs block below.
		[for b, fs in _gocmdparent_inputs
			for f in fs {"\(b)/\(f)"}],
	])
}

// === BEGIN GENERATED: _gocmdparent_inputs ===
// Per-brick in-brick file roster emitted by gocmdparent.
// Rewritten by `mise run gen`. Do not hand-edit this section.
// Pattern B (AIDR-00093 fold): see contracts-schema.cue header.

_gocmdparent_inputs: [string]: [...string]

_gocmdparent_inputs: {
	"tenant/library/go/cmd/check": ["deps.cue"]
	"tenant/library/go/cmd/check/brickcollision": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/check/contracts": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/check/crosstenantlit": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/check/latticeschema": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/app": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/awsconfig": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/cuetree": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/discordbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/env": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/fmt": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/gmailbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/gocmd": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/gocmdcue": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/gocmdparent": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/golib": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/image": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/infra": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/k3d": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/k8s": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/matrixbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/misetoml": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/modulebazel": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/oci": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/seed": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/slackbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/speclattice": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/telegrambot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/gen/versionsbzl": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/hatch": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/hatch/bzlmodupgrade": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/hatch/goupgrade": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/hatch/helmupgrade": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/hatch/miseupgrade": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/hatch/onboardacc": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/lattice": ["deps.cue"]
	"tenant/library/go/cmd/lattice/merge": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp": ["deps.cue"]
	"tenant/library/go/cmd/stamp/discordbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/gmailbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/gocmd": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/gocmdcue": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/gocmdparent": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/golib": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/helmapp": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/matrixbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/midas": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/skill": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/slackbot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/telegrambot": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/stamp/tenant": ["deps.cue", "service.go"]
}

// === END GENERATED: _gocmdparent_inputs ===
