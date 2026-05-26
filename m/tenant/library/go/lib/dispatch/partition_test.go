package dispatch

import (
	"sort"
	"testing"

	"github.com/defn/other/m/tenant/library/go/lib/hatch"
)

// boolPtr is a helper for the BrickInfo.Shared override field.
func boolPtr(b bool) *bool { return &b }

func TestPartitionBricks_NoSharedBricks(t *testing.T) {
	// All component bricks, no shared, no path-overlap. Each brick
	// is its own group.
	bricks := map[string]hatch.BrickInfo{
		"a": {Slug: "a", Path: "tenant/library/app/foo", Kind: "component"},
		"b": {Slug: "b", Path: "tenant/library/app/bar", Kind: "component"},
		"c": {Slug: "c", Path: "tenant/library/app/baz", Kind: "component"},
	}
	p := PartitionBricks(bricks)
	if len(p.Shared) != 0 {
		t.Errorf("Shared = %v, want empty", p.Shared)
	}
	if p.AgentCount() != 3 {
		t.Errorf("AgentCount = %d, want 3", p.AgentCount())
	}
}

func TestPartitionBricks_SharedAggregator(t *testing.T) {
	// Marking an aggregator brick shared splits its descendants
	// into separate groups instead of clustering them under the
	// aggregator.
	bricks := map[string]hatch.BrickInfo{
		"agg":   {Slug: "agg", Path: "agg", Kind: "component", Shared: boolPtr(true)},
		"agg-a": {Slug: "agg-a", Path: "agg/a", Kind: "component"},
		"agg-b": {Slug: "agg-b", Path: "agg/b", Kind: "component"},
		"agg-c": {Slug: "agg-c", Path: "agg/c", Kind: "component"},
	}
	p := PartitionBricks(bricks)
	if len(p.Shared) != 1 || p.Shared[0] != "agg" {
		t.Errorf("Shared = %v, want [agg]", p.Shared)
	}
	if p.AgentCount() != 3 {
		t.Errorf("AgentCount = %d, want 3 (one per leaf)", p.AgentCount())
	}
	// Each leaf is its own group root because their parent (agg) is shared.
	for _, want := range []string{"agg-a", "agg-b", "agg-c"} {
		if _, ok := p.Groups[want]; !ok {
			t.Errorf("group %q missing; got %v", want, mapKeys(p.Groups))
		}
	}
}

func TestPartitionBricks_NestedAggregator(t *testing.T) {
	// agg shared; agg/sub also shared; agg/sub/x leaf. The
	// non-shared chain breaks at every shared brick, so x is its
	// own group regardless of how many shared layers there are
	// above it.
	bricks := map[string]hatch.BrickInfo{
		"agg":       {Slug: "agg", Path: "agg", Kind: "component", Shared: boolPtr(true)},
		"agg-sub":   {Slug: "agg-sub", Path: "agg/sub", Kind: "component", Shared: boolPtr(true)},
		"agg-sub-x": {Slug: "agg-sub-x", Path: "agg/sub/x", Kind: "component"},
	}
	p := PartitionBricks(bricks)
	if len(p.Shared) != 2 {
		t.Errorf("Shared = %v, want 2 entries", p.Shared)
	}
	if p.AgentCount() != 1 {
		t.Errorf("AgentCount = %d, want 1", p.AgentCount())
	}
	if _, ok := p.Groups["agg-sub-x"]; !ok {
		t.Errorf("expected leaf x to be its own group")
	}
}

func TestPartitionBricks_NonComponentInferredShared(t *testing.T) {
	// Branch bricks without an explicit `shared` field still get
	// treated as shared by default (via BrickInfo.IsShared rule).
	bricks := map[string]hatch.BrickInfo{
		"app":   {Slug: "app", Path: "app", Kind: "branch"},
		"app-a": {Slug: "app-a", Path: "app/a", Kind: "component"},
		"app-b": {Slug: "app-b", Path: "app/b", Kind: "component"},
	}
	p := PartitionBricks(bricks)
	if len(p.Shared) != 1 || p.Shared[0] != "app" {
		t.Errorf("Shared = %v, want [app]", p.Shared)
	}
	if p.AgentCount() != 2 {
		t.Errorf("AgentCount = %d, want 2", p.AgentCount())
	}
}

func TestPartitionBricks_ParentAndChildNonShared(t *testing.T) {
	// When the parent is non-shared, the child clusters into the
	// same group (the topmost non-shared ancestor wins).
	bricks := map[string]hatch.BrickInfo{
		"parent": {Slug: "parent", Path: "p", Kind: "component"},
		"child":  {Slug: "child", Path: "p/c", Kind: "component"},
	}
	p := PartitionBricks(bricks)
	if p.AgentCount() != 1 {
		t.Errorf("AgentCount = %d, want 1 (parent + child cluster)", p.AgentCount())
	}
	got, ok := p.Groups["parent"]
	if !ok {
		t.Fatalf("group 'parent' missing")
	}
	sort.Strings(got)
	if len(got) != 2 || got[0] != "child" || got[1] != "parent" {
		t.Errorf("group members = %v, want [child parent]", got)
	}
}

func TestPartitionBricks_DisjointGroupsAreIndependent(t *testing.T) {
	// Two disjoint subtrees with a shared root produce two
	// independent groups -- the coordinator can dispatch them in
	// parallel without coordination.
	bricks := map[string]hatch.BrickInfo{
		"root":  {Slug: "root", Path: "root", Kind: "component", Shared: boolPtr(true)},
		"x":     {Slug: "x", Path: "root/x", Kind: "component"},
		"x-sub": {Slug: "x-sub", Path: "root/x/sub", Kind: "component"},
		"y":     {Slug: "y", Path: "root/y", Kind: "component"},
		"y-sub": {Slug: "y-sub", Path: "root/y/sub", Kind: "component"},
	}
	p := PartitionBricks(bricks)
	if p.AgentCount() != 2 {
		t.Fatalf("AgentCount = %d, want 2", p.AgentCount())
	}
	xGroup := p.Groups["x"]
	yGroup := p.Groups["y"]
	if len(xGroup) != 2 || len(yGroup) != 2 {
		t.Errorf("groups: x=%v, y=%v; want 2 members each", xGroup, yGroup)
	}
}

func TestPartitionBricks_RootSlugSkipped(t *testing.T) {
	// The empty-slug root brick is always omitted; otherwise it'd
	// dominate every group.
	bricks := map[string]hatch.BrickInfo{
		"":  {Slug: "", Path: "", Kind: "branch"},
		"a": {Slug: "a", Path: "a", Kind: "component"},
	}
	p := PartitionBricks(bricks)
	if len(p.Shared) != 0 {
		t.Errorf("Shared = %v, want empty (root skipped)", p.Shared)
	}
	if p.AgentCount() != 1 {
		t.Errorf("AgentCount = %d, want 1", p.AgentCount())
	}
}

func mapKeys(m map[string][]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
