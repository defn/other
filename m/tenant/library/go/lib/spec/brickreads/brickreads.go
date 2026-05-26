// Package brickreads implements the read/write merge-diff staleness
// check from AIDR-00131.
//
// When the planner dispatches K bricks to K parallel sub-agents, the
// AIDR-00098 pairwise-write-intersection vet has already proved no
// two siblings will write to the same path. The remaining correctness
// gap is staleness: a sub-agent's read input may have been mutated by
// a sibling brick's writes during the same dispatch round, so its
// result is computed from inputs the trunk no longer has.
//
// Diff answers "for each completed brick Z, did any sibling brick's
// writes intersect Z's reads?". The output is a slice of staleness
// findings (Brick, Sibling, Paths). The future caller -- either the
// coordinator's pre-merge gate (AIDR-00131 architectural target a) or
// `defn hatch --brick=<path>`'s self-check on entry (target c) --
// consumes these findings to decide whether to re-dispatch the stale
// brick or abort with `blocked` per AIDR-00089.
//
// This package has no caller today. It mirrors the brickcollision
// AIDR-00098-as-built shape: pure function with txtar-fixtured
// table-driven tests, deferred production wiring.
//
// Tests live in brickreads_test.go using testscript + txtar fixtures
// (testdata/*.txtar).
package brickreads

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"
)

// Brick is the minimal projection of a brick needed by the staleness
// check. Only the path is required; ancestor detection is via
// path-prefix (same predicate as brickcollision).
type Brick struct {
	Path string `json:"path"`
}

// BrickIO is the per-brick fingerprint. Reads carry path/glob entries;
// Writes carry concrete paths. Globs in Reads are matched via
// path/filepath.Match against sibling Writes; concrete paths are
// matched by string equality.
type BrickIO struct {
	Reads  []string `json:"reads"`
	Writes []string `json:"writes,omitempty"`
}

// Stale reports a single staleness finding: brick `Brick` declared
// reads that intersect the writes of `Sibling`. Paths is the sorted
// list of intersecting concrete paths (globs expanded against the
// sibling's actual writes).
type Stale struct {
	Brick   string   `json:"brick"`
	Sibling string   `json:"sibling"`
	Paths   []string `json:"paths"`
}

// Format renders a Stale as a one-line human-readable string,
// shape: "<Brick> stale on <Sibling>: <path1>, <path2>, ...".
func (s Stale) Format() string {
	return fmt.Sprintf("%s stale on %s: %s", s.Brick, s.Sibling, strings.Join(s.Paths, ", "))
}

// Diff computes staleness across a dispatch round. `bricks` provides
// the slug -> Brick map for ancestor-skip; `completed` provides the
// per-brick fingerprints. Returns one Stale entry per (brick, sibling)
// pair with a non-empty intersection, sorted by Brick then Sibling.
//
// Algorithm:
//
//   - For each brick Z and each sibling S != Z, intersect Z.Reads with
//     S.Writes. Concrete reads match writes by string equality; glob
//     reads match writes via path/filepath.Match.
//   - Self-loops (Z == S) are skipped: a brick reading its own writes
//     is not a staleness signal -- it's just the brick's normal
//     in-place mutation.
//   - Ancestor pairs are skipped (mirroring brickcollision): the
//     coordinator never dispatches parent + descendant in parallel,
//     so a parent's transitive writes (via path-prefix attribution
//     per AIDR-00097) can't make a descendant stale relative to the
//     parent.
//
// Output Paths within each Stale is the deduplicated, sorted list of
// concrete sibling-write paths the read entries matched against.
func Diff(bricks map[string]Brick, completed map[string]BrickIO) []Stale {
	type key struct{ brick, sibling string }
	matches := map[key]map[string]bool{}

	for brick, io := range completed {
		for sibling, sibIO := range completed {
			if brick == sibling {
				continue
			}
			if isAncestor(bricks, brick, sibling) || isAncestor(bricks, sibling, brick) {
				continue
			}
			for _, r := range io.Reads {
				for _, w := range sibIO.Writes {
					if !matchReadWrite(r, w) {
						continue
					}
					k := key{brick, sibling}
					m, ok := matches[k]
					if !ok {
						m = map[string]bool{}
						matches[k] = m
					}
					m[w] = true
				}
			}
		}
	}

	out := make([]Stale, 0, len(matches))
	for k, m := range matches {
		paths := make([]string, 0, len(m))
		for p := range m {
			paths = append(paths, p)
		}
		sort.Strings(paths)
		out = append(out, Stale{Brick: k.brick, Sibling: k.sibling, Paths: paths})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Brick != out[j].Brick {
			return out[i].Brick < out[j].Brick
		}
		return out[i].Sibling < out[j].Sibling
	})
	return out
}

// matchReadWrite reports whether read entry r matches write path w.
// A read is a glob if it contains any of `*`, `?`, or `[`. Glob
// matching uses path/filepath.Match; failures from Match (malformed
// pattern) are treated as non-match rather than panicking, since a
// malformed read entry is a separate concern.
func matchReadWrite(r, w string) bool {
	if strings.ContainsAny(r, "*?[") {
		ok, err := filepath.Match(r, w)
		if err != nil {
			return false
		}
		return ok
	}
	return r == w
}

// isAncestor reports whether `a` is a strict ancestor of `b` by
// path-prefix. Same predicate as brickcollision.isAncestor; duplicated
// here to keep the package self-contained per AIDR-00131 future-work
// item F7 (extract once both consumers are stable).
func isAncestor(bricks map[string]Brick, a, b string) bool {
	bA, okA := bricks[a]
	bB, okB := bricks[b]
	if !okA || !okB {
		return false
	}
	if bA.Path == "" {
		return false
	}
	return strings.HasPrefix(bB.Path, bA.Path+"/")
}
