package dispatch

import (
	"sort"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/hatch"
)

// Partition splits a brick set into shared bricks (which the
// coordinator must merge itself) and disjoint sub-agent groups
// (each runnable in parallel without write collisions on shared
// state).
//
// Algorithm (path-based, today's lattice):
//
//  1. A brick is shared if BrickInfo.IsShared() returns true --
//     that's an explicit `shared: true` in the catalog OR the
//     inferred default (kind != "component"). The empty/root brick
//     is always shared because it spans everything.
//  2. Remaining (non-shared) bricks are grouped by their topmost
//     non-shared ancestor: two bricks land in the same group iff
//     one is an ancestor of the other along an unbroken chain of
//     non-shared bricks. Equivalently: remove every shared brick
//     from the path tree, and each surviving connected component
//     becomes one group.
//  3. The group's key is the slug of its topmost non-shared brick;
//     the coordinator can dispatch one sub-agent per group in
//     parallel. The shared list is the coordinator's own queue.
//
// Output is sorted (shared slugs ascending, group keys ascending,
// members ascending) so identical inputs produce identical plans.
type Partition struct {
	Shared []string            `json:"shared"`
	Groups map[string][]string `json:"groups"`
}

// AgentCount is how many sub-agents the partition allows the
// coordinator to fan out in parallel. One per group.
func (p Partition) AgentCount() int { return len(p.Groups) }

// sharedCandidate is a group root whose subtree is large enough
// that marking it shared would meaningfully increase the agent
// count. Returned in size-descending order.
type sharedCandidate struct {
	slug string
	size int
}

// suggestSharedCandidates returns up to 5 group roots whose member
// count exceeds threshold, sorted size-desc. The slug returned is
// the group's key (the topmost non-shared brick); mark THAT brick
// shared and the partition splits the group into one agent per
// direct child.
//
// Empty list when no group exceeds threshold -- the partition is
// already as parallel as path-overlap allows.
func suggestSharedCandidates(p Partition, threshold int) []sharedCandidate {
	cands := make([]sharedCandidate, 0, len(p.Groups))
	for slug, members := range p.Groups {
		if len(members) > threshold {
			cands = append(cands, sharedCandidate{slug: slug, size: len(members)})
		}
	}
	sort.Slice(cands, func(i, j int) bool {
		if cands[i].size != cands[j].size {
			return cands[i].size > cands[j].size
		}
		return cands[i].slug < cands[j].slug
	})
	if len(cands) > 5 {
		cands = cands[:5]
	}
	return cands
}

// PartitionBricks computes a Partition over the given brick set
// (typically from hatch.LoadBricks).
func PartitionBricks(bricks map[string]hatch.BrickInfo) Partition {
	// Index by path for O(1) ancestor lookups.
	pathToSlug := make(map[string]string, len(bricks))
	pathShared := make(map[string]bool, len(bricks))
	paths := make([]string, 0, len(bricks))
	for slug, b := range bricks {
		if slug == "" || b.Path == "" {
			continue
		}
		pathToSlug[b.Path] = slug
		pathShared[b.Path] = b.IsShared()
		paths = append(paths, b.Path)
	}
	sort.Strings(paths)

	// nearestAncestor: longest strict path-prefix in the brick set.
	nearestAncestor := func(p string) string {
		var best string
		for _, q := range paths {
			if q == p {
				continue
			}
			if !strings.HasPrefix(p, q+"/") {
				continue
			}
			if len(q) > len(best) {
				best = q
			}
		}
		return best
	}

	// groupRoot: walk up through non-shared ancestors and return
	// the topmost one (whose own parent is shared or absent).
	groupRoot := func(p string) string {
		current := p
		for {
			parent := nearestAncestor(current)
			if parent == "" || pathShared[parent] {
				return current
			}
			current = parent
		}
	}

	groups := map[string][]string{}
	var shared []string
	for _, p := range paths {
		slug := pathToSlug[p]
		if pathShared[p] {
			shared = append(shared, slug)
			continue
		}
		rootSlug := pathToSlug[groupRoot(p)]
		if rootSlug == "" {
			rootSlug = slug
		}
		groups[rootSlug] = append(groups[rootSlug], slug)
	}

	sort.Strings(shared)
	for k := range groups {
		sort.Strings(groups[k])
	}
	return Partition{Shared: shared, Groups: groups}
}
