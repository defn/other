package hatch

import (
	"reflect"
	"testing"
)

// Tests for the AIDR-00132 step 6 gen-subset selection. The
// inversion of `generators.<name>.paths` against a brick path is a
// pure function on the contract claims map; CycleBrick wires the
// real loader on top.

func TestSelectGenSubset_Empty(t *testing.T) {
	got := SelectGenSubset(nil, "any/brick")
	if len(got) != 0 {
		t.Fatalf("got %v, want []", got)
	}
}

func TestSelectGenSubset_PrefixMatch(t *testing.T) {
	claims := map[string][]string{
		"app":         {"tenant/library/app/foo/values.cue", "tenant/library/app/bar/values.cue"},
		"misetoml":    {"root/.config/mise/config.toml"},
		"versionsbzl": {"kernel/gen-versions/go.bzl"},
	}
	got := SelectGenSubset(claims, "tenant/library/app/foo")
	want := []string{"app"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestSelectGenSubset_MultipleHits_Sorted(t *testing.T) {
	// A brick at the lattice dir would catch both lattice (if it
	// were in the registry) and any other generator writing under
	// var/lattice/. Sorting keeps execution order
	// deterministic; the registry-miss check in runGenSubsetCycle
	// is what enforces aggregator exclusion.
	claims := map[string][]string{
		"alpha":     {"var/lattice/a.json"},
		"omega":     {"var/lattice/z.json"},
		"unrelated": {"go/cmd/foo/main.go"},
	}
	got := SelectGenSubset(claims, "var/lattice")
	want := []string{"alpha", "omega"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestSelectGenSubset_NoMatch(t *testing.T) {
	claims := map[string][]string{
		"app": {"tenant/library/app/foo/values.cue"},
	}
	got := SelectGenSubset(claims, "go/cmd/hello")
	if len(got) != 0 {
		t.Fatalf("got %v, want []", got)
	}
}

func TestSelectGenSubset_ExactPathMatch(t *testing.T) {
	// When a generator's claimed path equals brickPath (i.e. the
	// brick IS the file, e.g. a single-file brick), the inversion
	// must still pick the generator up. Without this case the
	// HasPrefix("brick/" ...) check would miss it.
	claims := map[string][]string{
		"single": {"go/cmd/foo/main.go"},
	}
	got := SelectGenSubset(claims, "go/cmd/foo/main.go")
	want := []string{"single"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestSelectGenSubset_PrefixMustBeBoundedByDir(t *testing.T) {
	// "go/cmd/foo" must not match "go/cmd/foobar/...". Without the
	// trailing slash the naive prefix check would. AIDR-00132 §6
	// inversion is dir-bounded.
	claims := map[string][]string{
		"sibling": {"go/cmd/foobar/main.go"},
	}
	got := SelectGenSubset(claims, "go/cmd/foo")
	if len(got) != 0 {
		t.Fatalf("got %v, want [] (foobar/ is not under foo/)", got)
	}
}

func TestPathsOutsideBrick(t *testing.T) {
	paths := []string{
		"go/cmd/foo/main.go",
		"go/cmd/foo/sub/x.go",
		"go/cmd/bar/main.go", // outside
		"unrelated.txt",      // outside
	}
	got := PathsOutsideBrick(paths, "go/cmd/foo")
	want := []string{"go/cmd/bar/main.go", "unrelated.txt"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestPathsOutsideBrick_AllInside(t *testing.T) {
	paths := []string{"go/cmd/foo/a.go", "go/cmd/foo/b.go"}
	got := PathsOutsideBrick(paths, "go/cmd/foo")
	if len(got) != 0 {
		t.Fatalf("got %v, want []", got)
	}
}

func TestLoadGeneratorClaims_SmokeAgainstWorkspace(t *testing.T) {
	// Smoke test: load the actual repo's per-generator contracts and
	// verify a known-stable entry shows up. Guards against accidental
	// breakage of the CUE load path (e.g. import-path drift). Walk
	// up from the test cwd to find cue.mod/module.cue so the test
	// works from any subdirectory.
	//
	// We assert against `cuetree` because its `paths` is a literal
	// one-entry list -- it survives the thin-vet load that uses
	// placeholder `tree`/`bricks` values. Pattern-A generators
	// (lattice, restamp) yield empty path lists in this mode
	// because their comprehensions iterate placeholders.
	workDir, err := FindWorkspaceRoot()
	if err != nil {
		t.Skipf("workspace root not found from test cwd: %v", err)
	}
	claims, err := LoadGeneratorClaims(workDir)
	if err != nil {
		t.Fatalf("LoadGeneratorClaims: %v", err)
	}
	got, ok := claims["cuetree"]
	if !ok {
		t.Fatalf("expected `cuetree` in claims; got keys %v", keysOf(claims))
	}
	if !contains(got, "var/gen-manifest.cue") {
		t.Errorf("cuetree paths %v missing literal var/gen-manifest.cue", got)
	}

	// Pattern A (catalog comprehension): lattice's paths are derived
	// from the lattice tree itself. The unification with lattice JSON
	// must yield concrete shard paths -- otherwise the gen-subset
	// inversion would silently miss every Pattern-A generator and
	// per-brick hatch would treat heavily-generated bricks as pure
	// hand-edited.
	lp, ok := claims["lattice"]
	if !ok {
		t.Fatalf("expected `lattice` in claims; got keys %v", keysOf(claims))
	}
	if !contains(lp, "var/lattice/_index.json") {
		t.Errorf("lattice paths %v missing var/lattice/_index.json (Pattern-A comprehension didn't resolve)", lp)
	}
}

func contains(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

func keysOf(m map[string][]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
