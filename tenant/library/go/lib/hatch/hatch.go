// Package hatch provides the core gen + build + sync cycle for reaching
// workspace equilibrium after stamp or upgrade changes.
package hatch

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	gosync "sync"

	gencmd "github.com/defn/other/m/tenant/library/go/cmd/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/buildsync"
	"github.com/defn/other/m/tenant/library/go/lib/gen/lattice"
	"github.com/defn/other/m/tenant/library/go/lib/gen/validate"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// MaxCycleIterations bounds Cycle's fixed-point loop. Real cascades
// (helm-bump -> chart_versions shard -> _index.json) settle in 2-3
// passes; 5 leaves headroom without masking a runaway gen. Operators
// can override via DEFN_HATCH_MAX_ITERATIONS env var (clamped to
// [1, maxCycleIterationsCeiling]) for legitimately deeper cascades.
// AIDR-00127 #10.
const MaxCycleIterations = 5

const maxCycleIterationsCeiling = 50

// resolveMaxCycleIterations reads DEFN_HATCH_MAX_ITERATIONS, clamps,
// returns MaxCycleIterations on absent/invalid/out-of-range. Logs
// once when the env override is in effect so operators can confirm.
func resolveMaxCycleIterations() int {
	v := os.Getenv("DEFN_HATCH_MAX_ITERATIONS")
	if v == "" {
		return MaxCycleIterations
	}
	n, err := strconv.Atoi(v)
	if err != nil || n < 1 || n > maxCycleIterationsCeiling {
		fmt.Printf("✓ hatch: DEFN_HATCH_MAX_ITERATIONS=%q ignored (must be int in [1,%d]); using default %d\n",
			v, maxCycleIterationsCeiling, MaxCycleIterations)
		return MaxCycleIterations
	}
	fmt.Printf("✓ hatch: DEFN_HATCH_MAX_ITERATIONS=%d (override; default %d)\n", n, MaxCycleIterations)
	return n
}

// Cycle runs gen + build (no tests) + sync repeatedly until reaching
// equilibrium (a pass where no file content changed) or
// MaxCycleIterations is exhausted. Returns the gen context from the
// final pass.
//
// Errors with "hatch did not reach idempotence" if the bound is hit
// with a still-non-zero changed count -- the convergence guarantee
// is the contract. Use CycleOnce when the caller deliberately wants
// the raw single-pass result without that guarantee.
func Cycle() (*gen.Context, error) {
	genCtx, err := gencmd.NewGenContext()
	if err != nil {
		return nil, fmt.Errorf("init gen context: %w", err)
	}
	maxIters := resolveMaxCycleIterations()
	var lastChanged []string
	for i := 1; i <= maxIters; i++ {
		changed, err := runCycle(genCtx, false)
		if err != nil {
			return nil, err
		}
		lastChanged = changed
		if len(changed) == 0 {
			return genCtx, nil
		}
	}
	return genCtx, fmt.Errorf("hatch did not reach idempotence in %d iterations (last pass: %d files changed)\n%s",
		maxIters, len(lastChanged), formatChangedFiles(lastChanged, 10))
}

// formatChangedFiles renders up to maxShow paths as a "  - <path>"
// indented list, with a "  ... and N more" footer when truncated.
// Used in the non-convergence error so operators can localize the
// cycle without grepping logs from all 5 hatch passes.
func formatChangedFiles(files []string, maxShow int) string {
	if len(files) == 0 {
		return ""
	}
	var sb strings.Builder
	for i, f := range files {
		if i >= maxShow {
			fmt.Fprintf(&sb, "  ... and %d more\n", len(files)-maxShow)
			break
		}
		fmt.Fprintf(&sb, "  - %s\n", f)
	}
	return sb.String()
}

// CycleOnce runs exactly one gen+build+sync pass and returns the gen
// context without asserting idempotence. By contract this can leave
// the workspace mid-cascade -- callers either don't care (debugging)
// or are running their own outer loop. Cycle is what production
// callers want.
func CycleOnce() (*gen.Context, error) {
	genCtx, err := gencmd.NewGenContext()
	if err != nil {
		return nil, fmt.Errorf("init gen context: %w", err)
	}
	if _, err := runCycle(genCtx, false); err != nil {
		return nil, err
	}
	return genCtx, nil
}

// CycleAndValidate runs gen + build + test + sync + validation (full
// pipeline). Single-pass by design: validation is the terminal step
// and tests do not mutate source, so iterating would only repeat
// work. Run Cycle first to reach equilibrium, then CycleAndValidate
// to verify.
func CycleAndValidate() error {
	genCtx, err := gencmd.NewGenContext()
	if err != nil {
		return fmt.Errorf("init gen context: %w", err)
	}

	_, err = runCycle(genCtx, true)
	return err
}

// runCycle returns the list of git-tracked files whose content
// changed during this pass (sorted). len() == 0 means idempotent.
func runCycle(genCtx *gen.Context, withTests bool) ([]string, error) {
	genCtx.Quiet = true

	// Snapshot mtimes so we can report the real gen delta rather than
	// the count of log lines (which is stable across no-op runs by
	// design -- see T6 in AIDR-00058).
	mtimesBefore, _ := snapshotMtimes(genCtx)

	genOut, err := CaptureOutput(func() error {
		genCtx.Quiet = false
		return gencmd.RunFullPipeline(genCtx)
	})
	if err != nil {
		return nil, fmt.Errorf("gen: %w", err)
	}

	genLines := parseLines(genOut, regexp.MustCompile(`^. generated ([^\s]+?)/?\s`))

	// Order: lattice BEFORE buildsync. Lattice writes
	// kernel/spec/lattice/_index.json with sha256 fingerprints of
	// every shard. The validation tests run by `bazel test` (inside
	// buildsync.Run when withTests=true) read _index.json and
	// verify it matches actual shard content. If lattice runs
	// AFTER buildsync, the tests see the previous run's stale
	// _index.json and fail with "shard sha256 mismatch" whenever
	// gen rewrote a shard this pass (e.g., chart_versions.json
	// after an irsa.cue rotation). buildsync only WRITES files
	// outside kernel/spec/lattice/ (package.json, go.mod, k3d.yaml,
	// mise.toml, gen-app.cue, app_kustomize.yaml -- see
	// buildsync.go:54+), so lattice's fingerprint inputs don't
	// depend on buildsync output. AIDR-00127 #1.
	latticeCtx := *genCtx
	latticeCtx.Quiet = true
	if latticeErr := lattice.Run(&latticeCtx); latticeErr != nil {
		return nil, fmt.Errorf("lattice: %w", latticeErr)
	}

	var syncOut string
	var syncErr error
	if withTests {
		syncOut, syncErr = CaptureOutput(func() error {
			return buildsync.Run(genCtx)
		})
	} else {
		syncOut, syncErr = CaptureOutput(func() error {
			return buildsync.RunBuildOnly(genCtx)
		})
	}
	if syncErr != nil {
		return nil, fmt.Errorf("sync: %w", syncErr)
	}
	if msg := lattice.Status(genCtx.WorkDir); msg != "" {
		genCtx.LogOK(msg)
	}

	// Stage all changes.
	if err := genCtx.GitAddAll(); err != nil {
		return nil, fmt.Errorf("git add: %w", err)
	}

	// Parse sync output.
	syncLines := parseLines(syncOut, regexp.MustCompile(`^. synced: (.+)$`))
	digestCount := countPrefix(syncOut, "\u2713 helm chart ")

	// Write tracking files.
	sort.Strings(genLines)
	sort.Strings(syncLines)
	workDir := genCtx.WorkDir
	if _, err := gen.WriteIfChanged(filepath.Join(workDir, "kernel/spec/gen-files.txt"),
		[]byte(strings.Join(genLines, "\n")+"\n"), 0o644); err != nil {
		return nil, fmt.Errorf("write gen-files.txt: %w", err)
	}
	if _, err := gen.WriteIfChanged(filepath.Join(workDir, "kernel/spec/sync-files.txt"),
		[]byte(strings.Join(syncLines, "\n")+"\n"), 0o644); err != nil {
		return nil, fmt.Errorf("write sync-files.txt: %w", err)
	}

	label := "hatch"
	if withTests {
		label = "gen"
	}
	// Report real deltas, not log-line counts. T1/T3/T4 guarantee
	// mtime is preserved on byte-identical writes, so mtime-advanced
	// files correspond to real content changes.
	changedFiles := mtimeChanges(genCtx, mtimesBefore)
	changed := len(changedFiles)
	if changed == 0 {
		fmt.Printf("\u2713 %s: idempotent (%d outputs tracked)\n", label, len(genLines))
	} else {
		fmt.Printf("\u2713 %s: %d files changed (%d outputs tracked)\n", label, changed, len(genLines))
	}
	fmt.Printf("\u2713 %s: %d files synced, %d chart digests\n", label, len(syncLines), digestCount)

	// Validate only when running with tests.
	if withTests {
		var imgErr, bzlErr error
		var valWg gosync.WaitGroup
		valWg.Add(2)
		go func() {
			defer valWg.Done()
			imgErr = validate.CheckImages(genCtx)
		}()
		go func() {
			defer valWg.Done()
			bzlErr = validate.CheckBazelCoverage(genCtx)
		}()
		valWg.Wait()

		if imgErr != nil {
			return nil, fmt.Errorf("check-images: %w", imgErr)
		}
		if bzlErr != nil {
			return nil, fmt.Errorf("check-bazel: %w", bzlErr)
		}
	}

	return changedFiles, nil
}

// CaptureOutput delegates to runner.CaptureSilent -- the gen + sync
// phases produce hundreds of per-file "generated <path>" / "synced
// <path>" lines; we capture for parsing (genLines, syncLines
// counts) but suppress the live tee. Final summary lines printed
// from runCycle are the operator's signal.
// See go/lib/runner/runner.go for capture / silent semantics.
func CaptureOutput(fn func() error) (string, error) {
	return runner.CaptureSilent(fn)
}

func parseLines(output string, re *regexp.Regexp) []string {
	var result []string
	for _, line := range strings.Split(output, "\n") {
		m := re.FindStringSubmatch(line)
		if len(m) > 1 && m[1] != "" {
			result = append(result, m[1])
		}
	}
	return result
}

func countPrefix(output, prefix string) int {
	count := 0
	for _, line := range strings.Split(output, "\n") {
		if strings.HasPrefix(line, prefix) {
			count++
		}
	}
	return count
}

func snapshotMtimes(genCtx *gen.Context) (map[string]int64, error) {
	out, err := genCtx.Sh("git", "ls-files")
	if err != nil {
		return nil, err
	}
	result := make(map[string]int64, 4096)
	for _, f := range strings.Split(strings.TrimSpace(out), "\n") {
		if f == "" {
			continue
		}
		info, err := os.Stat(filepath.Join(genCtx.WorkDir, f))
		if err != nil {
			continue
		}
		result[f] = info.ModTime().UnixNano()
	}
	return result, nil
}

// mtimeChanges returns the sorted list of git-tracked paths whose
// mtime advanced (or that didn't exist in `before`) since the
// snapshot. T1/T3/T4 mtime-preservation guarantees mean an advanced
// mtime corresponds to real content change. Stable order: git ls-files
// output is already sorted.
func mtimeChanges(genCtx *gen.Context, before map[string]int64) []string {
	if before == nil {
		return nil
	}
	out, err := genCtx.Sh("git", "ls-files")
	if err != nil {
		return nil
	}
	var changed []string
	for _, f := range strings.Split(strings.TrimSpace(out), "\n") {
		if f == "" {
			continue
		}
		info, err := os.Stat(filepath.Join(genCtx.WorkDir, f))
		if err != nil {
			continue
		}
		post := info.ModTime().UnixNano()
		pre, ok := before[f]
		if !ok || post > pre {
			changed = append(changed, f)
		}
	}
	return changed
}
