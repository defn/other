@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: gocmdcue generator.
//
// Traceability:
//   Go source:      go/lib/gen/gocmdcue/gocmdcue.go
//   Reads catalog:  catalog.go_cmd_cue_bricks (entries with
//                   implements="kernel/interface/go-cmd-cue")
//   Template:       interface/go-cmd-cue/templates.cue
//
// Why these files exist: the go-cmd-cue variant is for subcommands
// that validate their input against a CUE schema (schema.cue lives
// alongside, hand-written). Currently only `hello` implements this
// interface; as more CUE-validating commands land the claim list
// grows here.
//
// See AIDR-00062.

package contracts

import "list"

bricks: [string]: {
	path:       string
	stamp_type: string | *""
	...
}

generators: gocmdcue: {
	generator: "gocmdcue"
	source:    "tenant/library/go/lib/gen/gocmdcue"
	reason:    "stamps BUILD.bazel + command.go for each go-cmd-cue brick (CUE-validating subcommands)"
	read_from: {
		catalog: ["bricks"]
		paths: ["kernel/interface/go-cmd-cue/templates.cue"]
	}
	related_aidr: [62]
	paths: list.Concat([
		[
			for _, b in bricks
			if b.stamp_type == "go-cmd-cue"
			for f in ["BUILD.bazel", "command.go"] {"\(b.path)/\(f)"},
		],
		// In-brick hand-authored files (schema.cue, deps.cue, ...);
		// map populated by gocmdcue in the generated inputs block below.
		[for b, fs in _gocmdcue_inputs
			for f in fs {"\(b)/\(f)"}],
	])
}

// === BEGIN GENERATED: _gocmdcue_inputs ===
// Per-brick in-brick file roster emitted by gocmdcue.
// Rewritten by `mise run gen`. Do not hand-edit this section.
// Pattern B (AIDR-00093 fold): see contracts-schema.cue header.

_gocmdcue_inputs: [string]: [...string]

_gocmdcue_inputs: {
	"tenant/library/go/cmd/hello": ["deps.cue", "service.go"]
}

// === END GENERATED: _gocmdcue_inputs ===
