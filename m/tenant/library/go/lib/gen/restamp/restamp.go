// Package restamp re-runs StampBrick for all bricks with stamp_type.
//
// This is a gen phase that ensures brick catalog files stay in sync
// with the StampBrick template. If a refactor changes the template,
// gen auto-fixes all brick files. If nothing changed, it's a no-op.
//
// See AIDR-00045: stamp invocations are recorded in CUE (stamp_type field)
// so gen can mechanically re-derive them.
package restamp

import (
	"fmt"
	"path/filepath"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/brickpkg"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/stamp"
)

// Run re-stamps all bricks that have a stamp_type field.
func Run(ctx *gen.Context) error {
	bricks := ctx.CatalogQuery("bricks")

	type entry struct {
		path      string
		desc      string
		stampType string
		parent    string
	}
	var entries []entry

	if err := gen.IterMap(bricks, func(_ string, v cue.Value) error {
		st := v.LookupPath(cue.ParsePath("stamp_type"))
		if st.Err() != nil || !st.Exists() {
			return nil // skip bricks without stamp_type
		}
		stampType, _ := st.String()
		if stampType == "" || stampType == "gen" {
			return nil // skip empty or gen-managed bricks
		}

		path, _ := gen.DecodeString(v, "path")
		desc, _ := gen.DecodeString(v, "desc")
		parent, _ := gen.DecodeString(v, "parent")

		entries = append(entries, entry{
			path:      path,
			desc:      desc,
			stampType: stampType,
			parent:    parent,
		})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate bricks: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool { return entries[i].path < entries[j].path })

	for _, e := range entries {
		var opts []stamp.BrickOption
		if e.parent != "" {
			opts = append(opts, stamp.WithParent(e.parent))
		}

		// AIDR-00136: read the brick's dispatch.cue worker.reads /
		// worker.writes and pass them through so the catalog file
		// mirrors whatever the user has put in the worker. ok=false
		// means the brick has no on-disk worker (root branch, app
		// branch, cue.mod, freshly-stamped brick before its first
		// hatch) -- in those cases StampBrick defaults to empty
		// lists.
		brickDir := filepath.Join(ctx.WorkDir, e.path)
		reads, writes, ok, err := brickpkg.ReadWorkerIO(brickDir)
		if err != nil {
			return fmt.Errorf("read worker for %s: %w", e.path, err)
		}
		if ok {
			opts = append(opts, stamp.WithIO(reads, writes))
		}

		if err := stamp.StampBrick(ctx.WorkDir, e.stampType, e.path, e.desc, opts...); err != nil {
			return fmt.Errorf("restamp %s: %w", e.path, err)
		}
	}

	return nil
}
