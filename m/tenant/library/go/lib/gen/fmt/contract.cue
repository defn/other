@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: fmt generator.
//
// Traceability:
//   Go source:      go/lib/gen/fmt/fmt.go
//   Reads catalogs: catalog.formatters
//   Template:       interface/fmt/templates.cue
//
// Why these files exist: each formatter (cue, gofmt, buildifier,
// prettier, etc.) has a brick directory holding a formatter.cue
// config (hand-written) and a BUILD.bazel (stamped). The BUILD.bazel
// wires up the formatter for Bazel fmt_test rules.
//
// Not claimed: fmt/<name>/formatter.cue (hand-written), fmt/BUILD.bazel
// (top-level glue), fmt/.mise/tasks/* (hand-written Clojure scripts
// that run formatters).
//
// See AIDR-00062.

package contracts

// Bind catalog.formatters from the lattice JSON so the contract can
// iterate it directly (parallel to `tree: _` in contracts-schema.cue).
formatters: _

generators: fmt: {
	generator: "fmt"
	source:    "tenant/library/go/lib/gen/fmt"
	reason:    "stamps per-formatter BUILD.bazel from catalog.formatters so every fmt_test rule in the repo can resolve the right tool + version"
	read_from: {
		catalog: ["formatters"]
		paths: ["kernel/interface/fmt/templates.cue"]
	}
	related_aidr: [62]
	// Each formatter brick has a fixed file set. Iterating
	// catalog.formatters + crossing with the filenames yields the
	// full claim list -- no sidecar needed.
	paths: [
		for k, _ in formatters
		for f in ["BUILD.bazel", "formatter.cue"] {"kernel/fmt/\(k)/\(f)"},
	]
}
