package hatch

import (
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	gencmd "github.com/defn/other/m/tenant/library/go/cmd/gen"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
	"github.com/defn/other/m/tenant/library/go/lib/spec/brickreads"
)

// CycleBrickOpts captures the inputs to one per-brick equilibrium
// dispatch (AIDR-00132 F1).
type CycleBrickOpts struct {
	// Brick is the slug (e.g. "go--cmd--hello") or path (e.g.
	// "go/cmd/hello"). Resolved against the lattice bricks shard.
	Brick string

	// SinceSnapshot is the path to a CUE #DispatchPlan describing
	// writes-completed-since-dispatch. Empty = first wave; F1 self-
	// check trivially passes.
	SinceSnapshot string

	// ResultOut is the path to write the per-brick #BrickResult CUE.
	// Empty = informational / dev-iteration mode (status reported
	// only via stdout).
	ResultOut string

	// WorkDir overrides the default findWorkspaceRoot() behavior.
	// Set this to dispatch the agent into a specific git worktree
	// (the F2 isolation contract). Empty = derive from cwd.
	WorkDir string
}

// BrickInfo is the public projection of a lattice brick entry that
// the F1 primitive and the dispatch coordinator both need. Field
// shape matches var/lattice/bricks.json.gz; the JSON tags
// drive both the lattice decode and any caller round-tripping the
// record through CUE.
type BrickInfo struct {
	Path   string   `json:"path"`
	Slug   string   `json:"slug"`
	Kind   string   `json:"kind"`
	Reads  []string `json:"reads"`
	Shared *bool    `json:"shared,omitempty"`
}

// IsShared reports whether the brick is marked shared (explicitly
// or by inference). Explicit `shared: true` wins. When unset,
// non-component bricks (branch / relationship / interface) default
// to shared because they aggregate or span; components default to
// not-shared. The dispatch partitioner uses this to keep shared
// bricks on the coordinator's queue rather than fanning them out.
func (b BrickInfo) IsShared() bool {
	if b.Shared != nil {
		return *b.Shared
	}
	return b.Kind != "component"
}

// CycleBrick is the per-brick equilibrium primitive. It runs the F1
// staleness self-check against the snapshot, then iterates the
// contract-inverted gen subset (AIDR-00132 step 6) until the brick
// reaches a fixed point or hits MaxCycleIterations. For pure hand-
// edited bricks the subset is empty and the loop trivially exits
// after one zero-pass iteration. Cross-brick aggregators (lattice,
// cuetree, speclattice, buildsync) are intentionally excluded from
// the subset; they run at the coordinator's merge boundary.
func CycleBrick(opts CycleBrickOpts) error {
	if opts.Brick == "" {
		return fmt.Errorf("brick: --brick=<slug-or-path> is required")
	}
	workDir := opts.WorkDir
	if workDir == "" {
		var err error
		workDir, err = findWorkspaceRoot()
		if err != nil {
			return fmt.Errorf("find workspace root: %w", err)
		}
	}

	bricks, err := loadBricksShard(workDir)
	if err != nil {
		return fmt.Errorf("load bricks shard: %w", err)
	}
	this, ok := resolveBrick(bricks, opts.Brick)
	if !ok {
		return fmt.Errorf("brick %q not found in lattice (slug or path)", opts.Brick)
	}

	plan, err := LoadDispatchPlan(opts.SinceSnapshot)
	if err != nil {
		return fmt.Errorf("load snapshot: %w", err)
	}

	result := runBrickF1(this, bricks, plan)
	if result.Status == "blocked" {
		fmt.Printf("✗ hatch --brick=%s: blocked\n", this.Slug)
		for _, b := range result.BlockedOn {
			fmt.Printf("    on %s: %s\n", b.Sibling, strings.Join(b.Paths, ", "))
		}
		return emitResult(opts.ResultOut, result)
	}

	subset, err := computeGenSubset(workDir, this.Path)
	if err != nil {
		return fmt.Errorf("compute gen subset: %w", err)
	}
	if len(subset) > 0 {
		runResult, rerr := runGenSubsetCycle(workDir, this.Path, subset)
		if rerr != nil {
			return fmt.Errorf("gen subset: %w", rerr)
		}
		if runResult.Dirty {
			result.Status = "dirty"
			fmt.Printf("✗ hatch --brick=%s: dirty (writes outside brick: %s)\n",
				this.Slug, strings.Join(runResult.OutOfLane, ", "))
			return emitResult(opts.ResultOut, result)
		}
		if !runResult.Converged {
			result.Status = "not-converged"
			fmt.Printf("✗ hatch --brick=%s: not-converged after %d iterations\n",
				this.Slug, MaxCycleIterations)
			return emitResult(opts.ResultOut, result)
		}
	}

	fp, err := fingerprintBrick(workDir, this.Path)
	if err != nil {
		return fmt.Errorf("fingerprint: %w", err)
	}
	result.Fingerprint = fp
	if len(subset) == 0 {
		fmt.Printf("✓ hatch --brick=%s: idempotent (fingerprint %s)\n", this.Slug, shortFp(fp))
	} else {
		fmt.Printf("✓ hatch --brick=%s: idempotent (gen subset: %s, fingerprint %s)\n",
			this.Slug, strings.Join(subset, ","), shortFp(fp))
	}
	return emitResult(opts.ResultOut, result)
}

// genCycleResult bundles the outcome of one per-brick gen-subset
// cycle so CycleBrick can map it onto the BrickResult status field
// without re-deriving anything.
type genCycleResult struct {
	Converged bool     // gen-subset reached a no-mtime-change pass
	Dirty     bool     // a generator wrote files outside the brick
	OutOfLane []string // dirty paths (for the human-readable error)
}

// computeGenSubset is the seam tests stub to drive the cycle without
// touching disk. The default implementation reads contracts via
// LoadGeneratorClaims and selects by path-prefix.
var computeGenSubset = func(workDir, brickPath string) ([]string, error) {
	claims, err := LoadGeneratorClaims(workDir)
	if err != nil {
		return nil, err
	}
	return SelectGenSubset(claims, brickPath), nil
}

// runGenSubsetCycle is the seam tests stub to avoid invoking real
// generators (which need the full catalog overlay + Bazel state).
// Default impl creates a gen.Context for workDir then iterates
// AIDR-00132 step 7's bounded loop: snapshot mtimes, run each gen
// in subset, detect out-of-lane writes (step 9's `dirty` status),
// detect convergence by comparing mtime snapshots.
var runGenSubsetCycle = func(workDir, brickPath string, subset []string) (genCycleResult, error) {
	gctx, err := gencmd.NewGenContextAt(workDir)
	if err != nil {
		return genCycleResult{}, fmt.Errorf("init gen context: %w", err)
	}
	gctx.Quiet = true
	maxIters := resolveMaxCycleIterations()
	for i := 1; i <= maxIters; i++ {
		before, err := snapshotMtimes(gctx)
		if err != nil {
			return genCycleResult{}, fmt.Errorf("snapshot mtimes: %w", err)
		}
		for _, name := range subset {
			fn, ok := gencmd.PhaseAByContractName[name]
			if !ok {
				return genCycleResult{}, fmt.Errorf("generator %q not in PhaseAByContractName registry "+
					"(it may be an aggregator excluded from per-brick hatch -- see AIDR-00132 step 6)", name)
			}
			if err := fn(gctx); err != nil {
				return genCycleResult{}, fmt.Errorf("gen %s: %w", name, err)
			}
		}
		if err := gctx.GitAddAll(); err != nil {
			return genCycleResult{}, fmt.Errorf("git add: %w", err)
		}
		changed := mtimeChanges(gctx, before)
		out := PathsOutsideBrick(changed, brickPath)
		if len(out) > 0 {
			return genCycleResult{Dirty: true, OutOfLane: out}, nil
		}
		// changed is sorted git-ls order; if all surviving entries are
		// under brickPath and len(changed) == 0, equilibrium reached.
		if len(changed) == 0 {
			return genCycleResult{Converged: true}, nil
		}
	}
	return genCycleResult{}, nil
}

// runBrickF1 is the pure, testable core of CycleBrick: given the
// brick under dispatch, the slug -> BrickInfo lookup table, and
// the snapshot of completed siblings, produce a BrickResult with
// status `blocked` (with populated BlockedOn) or `idempotent` (with
// no fingerprint -- the caller fills that in).
//
// Pure function: no I/O, no global state. Tests construct the
// inputs directly and assert on the returned BrickResult.
func runBrickF1(this BrickInfo, siblings map[string]BrickInfo, snapshot *DispatchPlan) BrickResult {
	diffBricks := map[string]brickreads.Brick{
		this.Slug: {Path: this.Path},
	}
	diffIO := map[string]brickreads.BrickIO{
		this.Slug: {Reads: this.Reads},
	}
	if snapshot != nil {
		for slug, prior := range snapshot.Bricks {
			if slug == this.Slug {
				continue
			}
			sibling, ok := siblings[slug]
			if !ok {
				sibling = BrickInfo{Slug: slug}
			}
			diffBricks[slug] = brickreads.Brick{Path: sibling.Path}
			diffIO[slug] = brickreads.BrickIO{Writes: prior.Writes}
		}
	}

	stale := brickreads.Diff(diffBricks, diffIO)

	result := BrickResult{
		Reads:  append([]string(nil), this.Reads...),
		Writes: []string{},
	}
	for _, s := range stale {
		if s.Brick != this.Slug {
			continue
		}
		result.BlockedOn = append(result.BlockedOn, BlockedOn{
			Sibling: s.Sibling,
			Paths:   append([]string(nil), s.Paths...),
		})
	}
	if len(result.BlockedOn) > 0 {
		result.Status = "blocked"
	} else {
		result.Status = "idempotent"
	}
	return result
}

func emitResult(path string, r BrickResult) error {
	if path == "" {
		return nil
	}
	return WriteResultCUE(path, r)
}

func shortFp(fp string) string {
	if len(fp) <= 12 {
		return fp
	}
	return fp[:12]
}

// LoadBricks reads var/lattice/bricks.json.gz and returns a
// slug-keyed map of every brick the lattice tracks. Exposed so the
// dispatch coordinator can compute the involved set of a target
// brick without reimplementing the lattice load.
func LoadBricks(workDir string) (map[string]BrickInfo, error) {
	return loadBricksShard(workDir)
}

// AllComponentSlugs returns the slug-sorted list of component bricks
// from the lattice. Branch / relationship bricks and the root are
// excluded because they don't represent independent work units --
// they aggregate or annotate, but a dispatcher running CycleBrick
// against them would just fingerprint a tree it doesn't own. The
// caller is the AIDR-00132 / AIDR-00133 coordinator deciding which
// bricks to fan out.
func AllComponentSlugs(workDir string) ([]string, error) {
	bricks, err := loadBricksShard(workDir)
	if err != nil {
		return nil, err
	}
	var slugs []string
	for slug, b := range bricks {
		if b.Kind != "component" {
			continue
		}
		if slug == "" {
			continue
		}
		slugs = append(slugs, slug)
	}
	sort.Strings(slugs)
	return slugs, nil
}

// FindWorkspaceRoot is exported so callers outside the hatch package
// (e.g. the dispatch coordinator) share the same workspace-locating
// rule.
func FindWorkspaceRoot() (string, error) { return findWorkspaceRoot() }

// loadBricksShard reads var/lattice/bricks.json.gz and
// returns a slug -> BrickInfo map. The empty-path root brick (key
// "") is also included under slug "".
func loadBricksShard(workDir string) (map[string]BrickInfo, error) {
	path := filepath.Join(workDir, "var/lattice/bricks.json.gz")
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open %s: %w (run `mise run hatch` first to populate the lattice)", path, err)
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return nil, fmt.Errorf("gunzip %s: %w", path, err)
	}
	defer gz.Close()
	var raw map[string]BrickInfo
	if err := json.NewDecoder(gz).Decode(&raw); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	out := make(map[string]BrickInfo, len(raw))
	for catalogKey, b := range raw {
		slug := b.Slug
		if slug == "" {
			slug = catalogKey
		}
		b.Slug = slug
		out[slug] = b
	}
	return out, nil
}

// resolveBrick accepts either a slug or a path and returns the
// matching BrickInfo. Slug match wins over path match -- slugs
// are unique and short, paths are unique but more verbose.
func resolveBrick(bricks map[string]BrickInfo, key string) (BrickInfo, bool) {
	if b, ok := bricks[key]; ok {
		return b, true
	}
	for _, b := range bricks {
		if b.Path == key {
			return b, true
		}
	}
	return BrickInfo{}, false
}

// fingerprintBrick computes sha256 over the sorted concatenation of
// every git-tracked file's content under the brick path. Hidden
// behind sha256-of-sha256s so adding/removing files changes the
// fingerprint without re-hashing the whole tree.
func fingerprintBrick(workDir, brickPath string) (string, error) {
	files, err := trackedFilesUnder(workDir, brickPath)
	if err != nil {
		return "", err
	}
	sort.Strings(files)

	h := sha256.New()
	for _, f := range files {
		data, err := os.ReadFile(filepath.Join(workDir, f))
		if err != nil {
			return "", fmt.Errorf("read %s: %w", f, err)
		}
		fileH := sha256.Sum256(data)
		fmt.Fprintf(h, "%s %x\n", f, fileH)
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func trackedFilesUnder(workDir, brickPath string) ([]string, error) {
	// Run git from workDir so paths are relative to the workspace
	// root regardless of the user's cwd.
	args := []string{"git", "ls-files"}
	if brickPath != "" {
		args = append(args, "--", brickPath)
	}
	out, err := runner.Output(context.Background(), runner.Opts{Args: args, Dir: workDir})
	if err != nil {
		return nil, err
	}
	var files []string
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		files = append(files, line)
	}
	return files, nil
}

// findWorkspaceRoot walks up from the current working directory to
// find the defn workspace root. The marker is `cue.mod/module.cue` --
// every defn workspace has one, and (unlike `.git`) it pins the
// kernel/tenant root rather than an enclosing umbrella repo.
func findWorkspaceRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "cue.mod", "module.cue")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("no cue.mod/module.cue found above cwd")
		}
		dir = parent
	}
}
