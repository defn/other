package dispatch

import (
	"fmt"
	"sort"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/hatch"
)

// Plan computes the set of bricks a coordinator must include when
// the planner picks `target` as the work unit.
//
// Today the involvement rule is path-prefix only: target plus every
// brick whose path is an ancestor or descendant of target's path.
// This is cheap (the lattice already has paths), conservative (a
// worktree spanning the involved set captures every file the target's
// edits could read or write under its directory), and good enough
// while bricks still declare `reads: []` (AIDR-00131
// `_emptyBrickReads` vet, until AIDR-00132 OQ7 step 2 lands).
//
// Future work: extend with reads/writes intersection via
// brickreads.Diff once meaningful per-brick reads/writes declarations
// land. The function signature already accepts the BrickInfo map so
// adding criteria is a body-only edit, not a contract change.
func Plan(target string, bricks map[string]hatch.BrickInfo) ([]string, error) {
	resolved, ok := resolveTarget(target, bricks)
	if !ok {
		return nil, fmt.Errorf("dispatch plan: brick %q not found in lattice", target)
	}

	involvedSet := map[string]struct{}{resolved.Slug: {}}
	for slug, b := range bricks {
		if slug == "" {
			continue
		}
		if pathOverlaps(b.Path, resolved.Path) {
			involvedSet[slug] = struct{}{}
		}
	}

	involved := make([]string, 0, len(involvedSet))
	for slug := range involvedSet {
		involved = append(involved, slug)
	}
	sort.Strings(involved)
	return involved, nil
}

// pathOverlaps reports whether path-prefix relates a and b: equal,
// or one is an ancestor of the other. Empty paths (the root brick)
// are excluded -- the root "overlaps" with everything by definition,
// and including it in every plan defeats the point.
func pathOverlaps(a, b string) bool {
	if a == "" || b == "" {
		return false
	}
	if a == b {
		return true
	}
	return strings.HasPrefix(a, b+"/") || strings.HasPrefix(b, a+"/")
}

// resolveTarget accepts either a slug or a path and returns the
// matching BrickInfo (with Slug populated).
func resolveTarget(key string, bricks map[string]hatch.BrickInfo) (hatch.BrickInfo, bool) {
	if b, ok := bricks[key]; ok {
		b.Slug = key
		return b, true
	}
	for slug, b := range bricks {
		if b.Path == key {
			b.Slug = slug
			return b, true
		}
	}
	return hatch.BrickInfo{}, false
}
