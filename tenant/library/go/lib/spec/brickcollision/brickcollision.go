// Package brickcollision implements the pairwise-write-intersection
// check from AIDR-00098.
//
// Two bricks A and B (where neither is an ancestor of the other) may
// not share any path in their writes set. Such a pair cannot be
// dispatched to parallel sub-agents -- they would race on the shared
// file. Ancestor pairs are skipped because a coordinator never
// dispatches a parent + descendant in parallel; the descendant is
// part of the parent's subtree per AIDR-00097 path-prefix attribution.
//
// This package is the Go-side companion to the brick_io aggregation
// in m/kernel/spec/contracts-schema.cue. The CUE side derives the
// per-brick writes set; this Go side checks pairwise non-overlap.
//
// Tests live in brickcollision_test.go using testscript + txtar
// fixtures (testdata/*.txtar).
package brickcollision

import (
	"fmt"
	"sort"
	"strings"
)

// Brick is the minimal projection of a brick needed by the collision
// check. Only the path is required; ancestor detection is via
// path-prefix.
type Brick struct {
	Path string `json:"path"`
}

// BrickIO is the per-brick fingerprint. Reads are accepted in the
// shape but ignored by Check -- the collision hazard is on writes
// only. Reads are useful for the coordinator's merge-time evaluation
// (a separate concern, deferred to a follow-up AIDR).
type BrickIO struct {
	Writes []string `json:"writes"`
	Reads  []string `json:"reads,omitempty"`
}

// Collision names a pair of bricks that share at least one write
// path. Pair is the alphabetically-sorted "<A>__<B>" key per
// AIDR-00098 decision (a). A and B carry the individual slugs for
// programmatic access. Paths is the sorted list of shared write
// paths.
type Collision struct {
	Pair  string   `json:"pair"`
	A     string   `json:"a"`
	B     string   `json:"b"`
	Paths []string `json:"paths"`
}

// Format renders a Collision as a one-line human-readable string,
// shape: "<A>__<B> collide on: <path1>, <path2>, ...".
func (c Collision) Format() string {
	return fmt.Sprintf("%s collide on: %s", c.Pair, strings.Join(c.Paths, ", "))
}

// Check returns the sorted set of non-ancestor brick pairs that
// share any write path. Empty result means parallel dispatch on any
// non-ancestor pair is provably safe.
//
// Algorithm:
//
//   - Build path-inverted index over brick_io.writes; dedupe per path
//     so a brick whose writes list contains the same path twice
//     (e.g. via generator + manualFiles union with overlap) doesn't
//     produce a spurious self-pair.
//   - For each path with >1 distinct claimant, enumerate unordered
//     pairs (alphabetic) and skip ancestor pairs.
//   - Aggregate by pair so multiple shared paths produce one entry.
//
// Ancestor skip rule: A is ancestor of B iff B.Path begins with
// A.Path + "/". The check applies in either direction.
func Check(bricks map[string]Brick, brickIO map[string]BrickIO) []Collision {
	byPathSet := map[string]map[string]bool{}
	for slug, io := range brickIO {
		for _, p := range io.Writes {
			s, ok := byPathSet[p]
			if !ok {
				s = map[string]bool{}
				byPathSet[p] = s
			}
			s[slug] = true
		}
	}
	byPath := make(map[string][]string, len(byPathSet))
	for p, s := range byPathSet {
		slugs := make([]string, 0, len(s))
		for slug := range s {
			slugs = append(slugs, slug)
		}
		byPath[p] = slugs
	}

	pairs := map[string]*Collision{}
	for path, slugs := range byPath {
		if len(slugs) < 2 {
			continue
		}
		sorted := append([]string(nil), slugs...)
		sort.Strings(sorted)
		for i := 0; i < len(sorted); i++ {
			for j := i + 1; j < len(sorted); j++ {
				a, b := sorted[i], sorted[j]
				if isAncestor(bricks, a, b) || isAncestor(bricks, b, a) {
					continue
				}
				key := a + "__" + b
				c, ok := pairs[key]
				if !ok {
					c = &Collision{Pair: key, A: a, B: b}
					pairs[key] = c
				}
				c.Paths = append(c.Paths, path)
			}
		}
	}

	keys := make([]string, 0, len(pairs))
	for k := range pairs {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	out := make([]Collision, len(keys))
	for i, k := range keys {
		c := pairs[k]
		sort.Strings(c.Paths)
		out[i] = *c
	}
	return out
}

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
