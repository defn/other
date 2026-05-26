package hatch

import (
	"compress/gzip"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// Tests for the AIDR-00132 F1 self-check (runBrickF1). The pure
// function from (this brick info, sibling lookup, snapshot) to a
// BrickResult is the testable core; CycleBrick wraps it with disk
// I/O for the lattice load, snapshot read, and result write.
//
// Cases mirror AIDR-00132 §"Test shape", limited to what the F1
// self-check actually decides today (cases that depend on the
// path-filtered gen subset / cycle iteration cap are deferred until
// that subset becomes non-empty -- see open question 6).

func TestRunBrickF1_EmptySnapshot_Idempotent(t *testing.T) {
	this := BrickInfo{Slug: "a", Path: "go/cmd/a", Reads: []string{"shared/x.cue"}}
	got := runBrickF1(this, map[string]BrickInfo{"a": this}, &DispatchPlan{Bricks: map[string]BrickResult{}})

	if got.Status != "idempotent" {
		t.Fatalf("status = %q, want %q", got.Status, "idempotent")
	}
	if len(got.BlockedOn) != 0 {
		t.Fatalf("BlockedOn = %v, want empty", got.BlockedOn)
	}
	if len(got.Reads) != 1 || got.Reads[0] != "shared/x.cue" {
		t.Fatalf("Reads = %v, want [shared/x.cue]", got.Reads)
	}
}

func TestRunBrickF1_NilSnapshot_Idempotent(t *testing.T) {
	// Nil snapshot is the standalone case (--since-snapshot omitted).
	this := BrickInfo{Slug: "a", Path: "go/cmd/a"}
	got := runBrickF1(this, map[string]BrickInfo{"a": this}, nil)
	if got.Status != "idempotent" {
		t.Fatalf("status = %q, want idempotent", got.Status)
	}
}

func TestRunBrickF1_DisjointSnapshot_Idempotent(t *testing.T) {
	// Sibling completed and wrote files, but they don't intersect
	// this brick's reads. Should still be idempotent.
	this := BrickInfo{Slug: "a", Path: "go/cmd/a", Reads: []string{"shared/x.cue"}}
	bricks := map[string]BrickInfo{
		"a": this,
		"b": {Slug: "b", Path: "go/cmd/b"},
	}
	snap := &DispatchPlan{Bricks: map[string]BrickResult{
		"b": {Writes: []string{"unrelated/y.cue"}},
	}}
	got := runBrickF1(this, bricks, snap)
	if got.Status != "idempotent" {
		t.Fatalf("status = %q, want idempotent", got.Status)
	}
}

func TestRunBrickF1_ConcreteIntersection_Blocked(t *testing.T) {
	// AIDR-00132 fixture 4 / brickreads fixture 04: this brick's
	// reads intersect a sibling's writes. F1 must block with the
	// sibling and intersecting paths populated.
	this := BrickInfo{Slug: "a", Path: "go/cmd/a", Reads: []string{"shared/x.cue"}}
	bricks := map[string]BrickInfo{
		"a": this,
		"b": {Slug: "b", Path: "go/cmd/b"},
	}
	snap := &DispatchPlan{Bricks: map[string]BrickResult{
		"b": {Writes: []string{"shared/x.cue"}},
	}}
	got := runBrickF1(this, bricks, snap)
	if got.Status != "blocked" {
		t.Fatalf("status = %q, want blocked", got.Status)
	}
	if len(got.BlockedOn) != 1 {
		t.Fatalf("BlockedOn = %v, want 1 entry", got.BlockedOn)
	}
	if got.BlockedOn[0].Sibling != "b" {
		t.Fatalf("BlockedOn[0].Sibling = %q, want b", got.BlockedOn[0].Sibling)
	}
	if len(got.BlockedOn[0].Paths) != 1 || got.BlockedOn[0].Paths[0] != "shared/x.cue" {
		t.Fatalf("BlockedOn[0].Paths = %v, want [shared/x.cue]", got.BlockedOn[0].Paths)
	}
}

func TestRunBrickF1_GlobIntersection_Blocked(t *testing.T) {
	// brickreads fixture 07: glob read matches a concrete sibling
	// write via path/filepath.Match.
	this := BrickInfo{Slug: "a", Path: "go/cmd/a", Reads: []string{"shared/*.cue"}}
	bricks := map[string]BrickInfo{
		"a": this,
		"b": {Slug: "b", Path: "go/cmd/b"},
	}
	snap := &DispatchPlan{Bricks: map[string]BrickResult{
		"b": {Writes: []string{"shared/foo.cue"}},
	}}
	got := runBrickF1(this, bricks, snap)
	if got.Status != "blocked" {
		t.Fatalf("status = %q, want blocked", got.Status)
	}
	if len(got.BlockedOn) != 1 || got.BlockedOn[0].Paths[0] != "shared/foo.cue" {
		t.Fatalf("BlockedOn = %v, want [{b, [shared/foo.cue]}]", got.BlockedOn)
	}
}

func TestRunBrickF1_SelfWriteIgnored(t *testing.T) {
	// brickreads fixture 10: a brick reading its own writes is not a
	// staleness signal -- skipped at the brickreads.Diff layer.
	this := BrickInfo{Slug: "a", Path: "go/cmd/a", Reads: []string{"go/cmd/a/out.cue"}}
	bricks := map[string]BrickInfo{"a": this}
	snap := &DispatchPlan{Bricks: map[string]BrickResult{
		"a": {Writes: []string{"go/cmd/a/out.cue"}},
	}}
	got := runBrickF1(this, bricks, snap)
	if got.Status != "idempotent" {
		t.Fatalf("status = %q, want idempotent (self-read should be skipped)", got.Status)
	}
}

func TestRunBrickF1_AncestorPairIgnored(t *testing.T) {
	// brickreads fixture 11: parent + descendant pairs are skipped
	// because the coordinator never dispatches them in parallel.
	parent := BrickInfo{Slug: "p", Path: "go/cmd", Reads: []string{"go/cmd/child/out.cue"}}
	child := BrickInfo{Slug: "c", Path: "go/cmd/child"}
	bricks := map[string]BrickInfo{"p": parent, "c": child}
	snap := &DispatchPlan{Bricks: map[string]BrickResult{
		"c": {Writes: []string{"go/cmd/child/out.cue"}},
	}}
	got := runBrickF1(parent, bricks, snap)
	if got.Status != "idempotent" {
		t.Fatalf("status = %q, want idempotent (ancestor-pair skip)", got.Status)
	}
}

func TestRunBrickF1_BlockedResultRoundTrips(t *testing.T) {
	// WriteResultCUE + LoadBrickResult round-trip a blocked result
	// without losing the BlockedOn array. This exercises the CUE
	// wire format the coordinator consumes at merge time -- emitted
	// as JSON (CUE subset), decoded via cue.Value.Decode.
	this := BrickInfo{Slug: "a", Path: "go/cmd/a", Reads: []string{"shared/x.cue"}}
	bricks := map[string]BrickInfo{
		"a": this,
		"b": {Slug: "b", Path: "go/cmd/b"},
	}
	snap := &DispatchPlan{Bricks: map[string]BrickResult{
		"b": {Writes: []string{"shared/x.cue"}},
	}}
	r := runBrickF1(this, bricks, snap)

	tmp := t.TempDir() + "/result.cue"
	if err := WriteResultCUE(tmp, r); err != nil {
		t.Fatalf("WriteResultCUE: %v", err)
	}
	loaded, err := LoadBrickResult(tmp)
	if err != nil {
		t.Fatalf("LoadBrickResult: %v", err)
	}
	if loaded.Status != "blocked" {
		t.Fatalf("loaded.Status = %q, want blocked", loaded.Status)
	}
	if len(loaded.BlockedOn) != 1 || loaded.BlockedOn[0].Sibling != "b" {
		t.Fatalf("loaded.BlockedOn = %v, want [{b, [shared/x.cue]}]", loaded.BlockedOn)
	}
	if len(loaded.BlockedOn[0].Paths) != 1 || loaded.BlockedOn[0].Paths[0] != "shared/x.cue" {
		t.Fatalf("loaded.BlockedOn[0].Paths = %v", loaded.BlockedOn[0].Paths)
	}
}

func TestDispatchPlanRoundTrip(t *testing.T) {
	// LoadDispatchPlan must accept what WritePlanCUE emits, slug-
	// sorted with stable field ordering.
	plan := &DispatchPlan{Bricks: map[string]BrickResult{
		"alpha": {
			Reads: []string{"x"}, Writes: []string{}, Status: "idempotent",
			Fingerprint: "deadbeef",
		},
		"beta": {
			Reads: []string{}, Writes: []string{}, Status: "blocked",
			BlockedOn: []BlockedOn{{Sibling: "alpha", Paths: []string{"x"}}},
		},
	}}
	tmp := t.TempDir() + "/plan.cue"
	if err := WritePlanCUE(tmp, plan); err != nil {
		t.Fatalf("WritePlanCUE: %v", err)
	}
	loaded, err := LoadDispatchPlan(tmp)
	if err != nil {
		t.Fatalf("LoadDispatchPlan: %v", err)
	}
	if len(loaded.Bricks) != 2 {
		t.Fatalf("loaded.Bricks size = %d, want 2", len(loaded.Bricks))
	}
	if loaded.Bricks["alpha"].Fingerprint != "deadbeef" {
		t.Fatalf("alpha.Fingerprint = %q, want deadbeef", loaded.Bricks["alpha"].Fingerprint)
	}
	if loaded.Bricks["beta"].Status != "blocked" {
		t.Fatalf("beta.Status = %q, want blocked", loaded.Bricks["beta"].Status)
	}
}

// --- CycleBrick gen-subset tests (AIDR-00132 step 6) ---------------
//
// These tests stub `computeGenSubset` and `runGenSubsetCycle` so the
// tests don't depend on real contracts / generators / git state.
// The fixture creates a minimal workspace with a one-brick lattice
// shard so loadBricksShard succeeds.

func TestCycleBrick_GenSubset_Idempotent(t *testing.T) {
	dir := writeMinimalWorkspace(t, "go/cmd/foo")
	restore := stubSubset(t, []string{"fake"}, genCycleResult{Converged: true})
	defer restore()

	tmpResult := filepath.Join(t.TempDir(), "result.cue")
	if err := CycleBrick(CycleBrickOpts{
		Brick: "go--cmd--foo", WorkDir: dir, ResultOut: tmpResult,
	}); err != nil {
		t.Fatalf("CycleBrick: %v", err)
	}
	r, err := LoadBrickResult(tmpResult)
	if err != nil {
		t.Fatalf("LoadBrickResult: %v", err)
	}
	if r.Status != "idempotent" {
		t.Fatalf("status = %q, want idempotent", r.Status)
	}
	if r.Fingerprint == "" {
		t.Errorf("expected fingerprint to be set on idempotent")
	}
}

func TestCycleBrick_GenSubset_Dirty(t *testing.T) {
	dir := writeMinimalWorkspace(t, "go/cmd/foo")
	restore := stubSubset(t, []string{"fake"}, genCycleResult{
		Dirty: true, OutOfLane: []string{"unrelated/x.cue"},
	})
	defer restore()

	tmpResult := filepath.Join(t.TempDir(), "result.cue")
	if err := CycleBrick(CycleBrickOpts{
		Brick: "go--cmd--foo", WorkDir: dir, ResultOut: tmpResult,
	}); err != nil {
		t.Fatalf("CycleBrick: %v", err)
	}
	r, err := LoadBrickResult(tmpResult)
	if err != nil {
		t.Fatalf("LoadBrickResult: %v", err)
	}
	if r.Status != "dirty" {
		t.Fatalf("status = %q, want dirty", r.Status)
	}
}

func TestCycleBrick_GenSubset_NotConverged(t *testing.T) {
	dir := writeMinimalWorkspace(t, "go/cmd/foo")
	restore := stubSubset(t, []string{"fake"}, genCycleResult{Converged: false})
	defer restore()

	tmpResult := filepath.Join(t.TempDir(), "result.cue")
	if err := CycleBrick(CycleBrickOpts{
		Brick: "go--cmd--foo", WorkDir: dir, ResultOut: tmpResult,
	}); err != nil {
		t.Fatalf("CycleBrick: %v", err)
	}
	r, err := LoadBrickResult(tmpResult)
	if err != nil {
		t.Fatalf("LoadBrickResult: %v", err)
	}
	if r.Status != "not-converged" {
		t.Fatalf("status = %q, want not-converged", r.Status)
	}
}

func TestCycleBrick_GenSubset_EmptySkipsCycle(t *testing.T) {
	// Empty subset = pure hand-edited brick. The cycle loop must not
	// run, and the result must be idempotent with a fingerprint.
	dir := writeMinimalWorkspace(t, "go/cmd/foo")
	cycleCalled := false
	restoreCS := stubComputeGenSubset(t, func(_, _ string) ([]string, error) { return nil, nil })
	defer restoreCS()
	restoreRC := stubRunGenSubsetCycle(t, func(_, _ string, _ []string) (genCycleResult, error) {
		cycleCalled = true
		return genCycleResult{}, nil
	})
	defer restoreRC()

	tmpResult := filepath.Join(t.TempDir(), "result.cue")
	if err := CycleBrick(CycleBrickOpts{
		Brick: "go--cmd--foo", WorkDir: dir, ResultOut: tmpResult,
	}); err != nil {
		t.Fatalf("CycleBrick: %v", err)
	}
	if cycleCalled {
		t.Errorf("runGenSubsetCycle should not be called for empty subset")
	}
	r, err := LoadBrickResult(tmpResult)
	if err != nil {
		t.Fatalf("LoadBrickResult: %v", err)
	}
	if r.Status != "idempotent" {
		t.Fatalf("status = %q, want idempotent", r.Status)
	}
}

// stubSubset wires both seams to return a fixed subset name list and
// a fixed cycle result, bypassing real contracts loading and real
// generator execution.
func stubSubset(t *testing.T, names []string, result genCycleResult) func() {
	t.Helper()
	r1 := stubComputeGenSubset(t, func(_, _ string) ([]string, error) { return names, nil })
	r2 := stubRunGenSubsetCycle(t, func(_, _ string, _ []string) (genCycleResult, error) {
		return result, nil
	})
	return func() { r1(); r2() }
}

func stubComputeGenSubset(t *testing.T, fn func(string, string) ([]string, error)) func() {
	t.Helper()
	prev := computeGenSubset
	computeGenSubset = fn
	return func() { computeGenSubset = prev }
}

func stubRunGenSubsetCycle(t *testing.T, fn func(string, string, []string) (genCycleResult, error)) func() {
	t.Helper()
	prev := runGenSubsetCycle
	runGenSubsetCycle = fn
	return func() { runGenSubsetCycle = prev }
}

// writeMinimalWorkspace stands up a tmp workspace sufficient for
// CycleBrick: cue.mod/module.cue + git init + a one-brick lattice
// shard at kernel/spec/lattice/bricks.json.gz. The brick has the
// supplied path, slug derived from the path with '/' -> '--', and
// kind=component. Catalog/schema CUE packages are NOT created
// because the tests stub computeGenSubset, so NewGenContextAt is
// never reached.
func writeMinimalWorkspace(t *testing.T, brickPath string) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "cue.mod"), 0o755); err != nil {
		t.Fatalf("mkdir cue.mod: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "cue.mod", "module.cue"),
		[]byte(`module: "github.com/defn/other"`+"\n"), 0o644); err != nil {
		t.Fatalf("write module.cue: %v", err)
	}

	if err := os.MkdirAll(filepath.Join(dir, brickPath), 0o755); err != nil {
		t.Fatalf("mkdir brick: %v", err)
	}
	// Seed a single source file under the brick dir so fingerprint
	// has something to hash.
	if err := os.WriteFile(filepath.Join(dir, brickPath, "main.go"),
		[]byte("package foo\n"), 0o644); err != nil {
		t.Fatalf("write main.go: %v", err)
	}

	// One-brick shard: the test brick keyed by slug.
	slug := strings.ReplaceAll(brickPath, "/", "--")
	shard := map[string]BrickInfo{
		slug: {Path: brickPath, Slug: slug, Kind: "component"},
	}
	shardPath := filepath.Join(dir, "var", "lattice", "bricks.json.gz")
	if err := os.MkdirAll(filepath.Dir(shardPath), 0o755); err != nil {
		t.Fatalf("mkdir lattice: %v", err)
	}
	f, err := os.Create(shardPath)
	if err != nil {
		t.Fatalf("create shard: %v", err)
	}
	gz := gzip.NewWriter(f)
	if err := json.NewEncoder(gz).Encode(shard); err != nil {
		t.Fatalf("write shard: %v", err)
	}
	gz.Close()
	f.Close()

	// git init + add so fingerprintBrick's `git ls-files` returns
	// the seeded file. Using exec.Command directly because runner
	// pulls in the full gen.Context bootstrap.
	for _, args := range [][]string{
		{"init", "-q"},
		{"add", "-A"},
		{"-c", "user.email=test@example.com", "-c", "user.name=test", "commit", "-q", "-m", "init"},
	} {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	return dir
}

func TestWriteResultCUE_JSONShape(t *testing.T) {
	// Sanity check on the on-disk shape: WriteResultCUE emits JSON
	// (a CUE subset), so consumers can read it with `cue export`,
	// `jq`, or encoding/json. The schema at
	// m/kernel/spec/dispatch/dispatch_plan.cue is the contract.
	r := BrickResult{
		Reads:  []string{"shared/x.cue"},
		Writes: []string{},
		Status: "blocked",
		BlockedOn: []BlockedOn{
			{Sibling: "b", Paths: []string{"shared/x.cue"}},
		},
	}
	tmp := t.TempDir() + "/result.cue"
	if err := WriteResultCUE(tmp, r); err != nil {
		t.Fatalf("WriteResultCUE: %v", err)
	}
	data, err := os.ReadFile(tmp)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	out := string(data)
	for _, want := range []string{
		`"reads": [`,
		`"shared/x.cue"`,
		`"status": "blocked"`,
		`"sibling": "b"`,
		`"paths": [`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("WriteResultCUE output missing %q\nfull output:\n%s", want, out)
		}
	}
}
