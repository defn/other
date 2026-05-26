// Package dispatchworker stamps a default dispatch.cue into every
// brick's source dir.
//
// AIDR-00132 OQ7 step 2: each brick declares a `worker:
// dispatch.#BrickResult & {reads: [], writes: []}` co-located with
// its source files so AIDR-00132 OQ7 step 3 can replace the
// catalog's inline `reads: []` with `brick_io: <pkg>.worker`. The
// migration is mechanical -- one stub file per brick -- but two
// subproblems show up:
//
//	A. Bricks that already host CUE files must reuse the existing
//	   dir-local package (CUE forbids two packages in one dir).
//	   Resolved here by parsing the first .cue file in the dir for
//	   `package <name>` and reusing that name for dispatch.cue.
//
//	B. Bricks without any .cue files need a stub package name. We
//	   derive one from the path's last segment, sanitized to the
//	   CUE identifier shape `[a-zA-Z_][a-zA-Z_0-9]*`. Leading dots
//	   are dropped (".devcontainer" -> "devcontainer"); other
//	   non-identifier characters become underscores. Collisions
//	   between unrelated bricks are harmless because each brick
//	   dir hosts its own package -- CUE package names are
//	   dir-scoped.
//
// The contract claims one path per brick whose path resolves to a
// non-empty source dir (per `_brickHasFiles[slug]` from the
// contracts schema). See contract.cue.
package dispatchworker

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/brickpkg"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// importPath is the canonical CUE module path for the dispatch
// schema. The CUE module is `github.com/defn/other` (per
// cue.mod/module.cue), so the package at kernel/spec/dispatch/
// imports without the `/m/` prefix that mirrors the Go module path.
// AIDR-00132's "Schema locality" sketch shows /m/ -- it is wrong;
// the actual cue.mod has no /m/ root.
const importPath = "github.com/defn/other/kernel/spec/dispatch"

// Run iterates every brick whose path exists on disk and writes a
// default dispatch.cue declaring the worker.
func Run(ctx *gen.Context) error {
	bricks := ctx.CatalogQuery("bricks")
	if !bricks.Exists() {
		return nil
	}

	type entry struct {
		slug string
		path string
	}
	var entries []entry
	if err := gen.IterMap(bricks, func(slug string, b cue.Value) error {
		path, _ := gen.DecodeString(b, "path")
		if path == "" {
			return nil // root brick has no source dir
		}
		if brickpkg.IsCueModPath(path) {
			// CUE forbids packages inside cue.mod/ -- a dispatch.cue
			// there fails `cue fmt` with "cannot load packages
			// inside the cue.mod directory". The cue.mod brick is
			// the canonical case; the contract.cue comprehension
			// must mirror this skip so vet doesn't expect the file.
			return nil
		}
		entries = append(entries, entry{slug: gen.CueFieldKey(slug), path: path})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate bricks: %w", err)
	}

	// Sort for deterministic log output and stable parallel slot
	// assignment (helps reproducibility across runs).
	sort.Slice(entries, func(i, j int) bool { return entries[i].path < entries[j].path })

	written := 0
	for _, e := range entries {
		absDir := filepath.Join(ctx.WorkDir, e.path)
		info, err := os.Stat(absDir)
		if err != nil || !info.IsDir() {
			// Brick path is not a real dir on disk (the `app`
			// branch brick is the canonical case). Skip silently;
			// the contract excludes via _brickHasFiles, so vet
			// won't expect a file here.
			continue
		}
		pkg, err := brickpkg.DetectPackage(absDir, e.path)
		if err != nil {
			return fmt.Errorf("brick %s: detect package: %w", e.slug, err)
		}
		body := renderDispatchCUE(pkg)
		outPath := filepath.Join(absDir, brickpkg.DispatchFile)
		changed, werr := gen.WriteIfChanged(outPath, []byte(body), 0o644)
		if werr != nil {
			return fmt.Errorf("write %s: %w", outPath, werr)
		}
		if changed {
			written++
			ctx.LogOK(fmt.Sprintf("generated %s/%s", e.path, brickpkg.DispatchFile))
		}
	}

	if written > 0 && !ctx.Quiet {
		ctx.LogOK(fmt.Sprintf("dispatchworker: %d files written", written))
	}
	return nil
}

// renderDispatchCUE returns the canonical dispatch.cue body for a
// brick. The reads/writes default to empty lists -- the brick
// author edits in place once they have something to declare.
func renderDispatchCUE(pkg string) string {
	return fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

// AIDR-00132 OQ7: per-brick worker declaration. Edit `+"`reads`/`writes`"+`
// when this brick reads or writes any path the generator contracts
// don't already cover. The catalog imports `+"`worker`"+` (AIDR-00132
// OQ7 step 3) to project brick_io.

package %s

import "%s"

worker: dispatch.#BrickResult & {
	reads: []
	writes: []
}
`, pkg, importPath)
}
