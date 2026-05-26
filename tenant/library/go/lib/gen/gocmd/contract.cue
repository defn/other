@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: gocmd generator.
//
// Traceability:
//   Go source:      go/lib/gen/gocmd/gocmd.go
//   Reads catalog:  catalog.go_cmd_bricks (entries with
//                   implements="kernel/interface/go-cmd" and no parent)
//   Template:       interface/go-cmd/templates.cue
//
// Why these files exist: every top-level `defn` subcommand (build,
// pipeline, sync, version) is scaffolded from a go-cmd brick catalog
// entry. gocmd iterates entries without a parent field and stamps
// two files per entry: BUILD.bazel (Bazel wiring) and command.go
// (cobra command + fx wiring). The generator also writes
// go/lib/app/modules.go aggregating every command's fx Module,
// but that file lives outside go/cmd/ and is handled by
// go/lib/gen/gocmd/contract.cue separately once the go/lib
// subtree is scoped.
//
// Parent commands (bot, gen, hatch, infra, stamp) and their children
// are handled by gocmdparent, not gocmd. See
// go/lib/gen/gocmdparent/contract.cue.
//
// The go-cmd-cue variant (hello) is handled by gocmdcue, not gocmd.
// See go/lib/gen/gocmdcue/contract.cue.
//
// See AIDR-00061 (lattice schema vet) and AIDR-00062 (contracts).

package contracts

import "list"

// Iterate catalog.bricks filtered to top-level go-cmd (stamp_type ==
// "go-cmd" AND parent field empty -- children are handled by
// gocmdparent). Defaults on optional fields dodge "cannot reference
// optional field" in the comprehension.
bricks: [string]: {
	path:       string
	stamp_type: string | *""
	parent:     string | *""
	...
}

generators: gocmd: {
	generator: "gocmd"
	source:    "tenant/library/go/lib/gen/gocmd"
	reason:    "stamps BUILD.bazel + command.go for each top-level go-cmd brick (implements interface/go-cmd, no parent)"
	read_from: {
		catalog: ["bricks"]
		paths: ["kernel/interface/go-cmd/templates.cue"]
	}
	related_aidr: [62]
	paths: list.Concat([
		[
			for _, b in bricks
			if b.stamp_type == "go-cmd" if b.parent == ""
			for f in ["BUILD.bazel", "command.go"] {"\(b.path)/\(f)"},
		],
		// In-brick hand-authored files (service.go, deps.cue, ...);
		// map populated by gocmd in the generated inputs block below.
		[for b, fs in _gocmd_inputs
			for f in fs {"\(b)/\(f)"}],
	])
}

// === BEGIN GENERATED: _gocmd_inputs ===
// Per-brick in-brick file roster emitted by gocmd.
// Rewritten by `mise run gen`. Do not hand-edit this section.
// Pattern B (AIDR-00093 fold): see contracts-schema.cue header.

_gocmd_inputs: [string]: [...string]

_gocmd_inputs: {
	"tenant/library/go/cmd/bootstrap": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/build": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/dispatch": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/pipeline": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/sync": ["deps.cue", "service.go"]
	"tenant/library/go/cmd/version": ["deps.cue", "service.go"]
}

// === END GENERATED: _gocmd_inputs ===
