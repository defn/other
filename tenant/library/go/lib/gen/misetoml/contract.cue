@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: misetoml generator.
//
// Traceability:
//   Go source:   go/lib/gen/misetoml/misetoml.go
//   Reads:       schema.versions, schema.root_mise_tools
//
// Why these files exist: mise.toml at repo root is a minimal stub
// holding only [settings]/[env]/[task_config] because tool versions
// live in a *global* mise config (root/.config/mise/config.toml). The
// generator writes both from the same CUE source so they can never
// disagree. See AIDR-00062 for the contracts rationale.
//
// Important: modulebazel also writes to repo-root files (.bazelversion,
// MODULE.bazel). No collision here because misetoml owns mise.toml
// and misetoml's hand on root/.config/mise/config.toml is disjoint
// from modulebazel's path set.

package contracts

generators: misetoml: {
	generator: "misetoml"
	source:    "tenant/library/go/lib/gen/misetoml"
	reason:    "regenerates mise.toml + root/.config/mise/config.toml from schema.versions so tool version pins have one source of truth"
	read_from: {
		schema: ["versions"]
	}
	related_aidr: [62]
	paths: [
		"mise.toml",
		"root/.config/mise/config.toml",
	]
}
