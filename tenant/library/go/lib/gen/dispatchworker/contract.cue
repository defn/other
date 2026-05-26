@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: dispatchworker generator.
//
// Traceability:
//   Go source:      go/lib/gen/dispatchworker/dispatchworker.go
//   Reads catalogs: catalog.bricks
//   Reads schema:   kernel/spec/dispatch
//
// Why these files exist: AIDR-00132 OQ7 step 2. Each brick that has
// an on-disk source dir needs a `dispatch.cue` declaring its worker:
//
//   worker: dispatch.#BrickResult & {reads: [], writes: []}
//
// so `defn dispatch` can project the brick's reads/writes from a
// single canonical source. Catalog import wiring (step 3) lands as
// a follow-up; this generator unblocks it by guaranteeing the
// dispatch.cue exists at every brick path. See AIDR-00132 §"Schema
// locality" and OQ7 for the three-step migration plan.
//
// Path claim: every brick whose path resolves to a non-empty
// directory in the lattice tree (`_brickHasFiles[slug]` from
// contracts-schema.cue). The `app` branch brick (catalog-only,
// no on-disk path) is naturally excluded because the lattice tree
// has no `app/` entry.
//
// Per-brick CUE package: bricks that already host CUE files reuse
// that dir's existing package; bricks without any .cue files get a
// stub package derived from the path's last segment (sanitized to
// a valid CUE identifier). Both subproblems are resolved in
// dispatchworker.go's writeWorker() at gen time -- the contract
// only enumerates the file paths.
//
// See AIDR-00131 (worker.reads as the per-brick read declaration)
// and AIDR-00132 §"Schema locality" + OQ7.

package contracts

import "strings"

// dispatchworker activated 2026-05-10 after the BUILD.bazel-template
// migration completed (commits 7cf9650f / 8a79f131 / 5262e6b3 /
// 537bf0a4 / 40d44fbe). Every brick whose source dir resolves to a
// real on-disk directory now carries a `dispatch.cue` declaring
// `worker: dispatch.#BrickResult & {reads: [], writes: []}`. Catalog
// rewiring per AIDR-00132 OQ7 step 3 (replace inline `reads: []` with
// `brick_io: <pkg>.worker`) is the next sp-bricks task.
generators: dispatchworker: {
	generator: "dispatchworker"
	source:    "tenant/library/go/lib/gen/dispatchworker"
	reason:    "stamps a default `dispatch.cue` at each brick's source dir declaring `worker: dispatch.#BrickResult & {reads: [], writes: []}` so AIDR-00132 OQ7 step 3 can wire the catalog to import each brick's worker"
	read_from: {
		catalog: ["bricks"]
		paths: ["kernel/spec/dispatch/dispatch_plan.cue"]
	}
	related_aidr: [131, 132]
	// cue.mod and anything nested inside it is excluded -- CUE
	// forbids packages there, so a dispatch.cue would fail `cue fmt`
	// with "cannot load packages inside the cue.mod directory". The
	// dispatchworker.go Run loop applies the same skip; keep the two
	// in lockstep.
	paths: [
		for slug, b in bricks
		if b.path != ""
		if b.path != "cue.mod"
		if !strings.HasPrefix(b.path, "cue.mod/")
		if _brickHasFiles[slug] != _|_
		if _brickHasFiles[slug].has_files {"\(b.path)/dispatch.cue"},
	]
}
