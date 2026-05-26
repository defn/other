// Package pipeline implements the full gen pipeline: gen -> sync -> lattice.
// Replaces the babashka gen.clj orchestrator with a single Go process.
package pipeline

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	gosync "sync"

	gencmd "github.com/defn/other/m/tenant/library/go/cmd/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/buildsync"
	"github.com/defn/other/m/tenant/library/go/lib/gen/lattice"
	"github.com/defn/other/m/tenant/library/go/lib/gen/validate"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
	"github.com/spf13/cobra"
)

type Config struct{}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, _ Config, onReady func(error)) error {
	onReady(nil)
	return runPipeline()
}

func runPipeline() error {
	// Phase 1: gen (CUE generators + stamp files)
	genCtx, err := gencmd.NewGenContext()
	if err != nil {
		return fmt.Errorf("init gen context: %w", err)
	}
	genCtx.Quiet = true

	// Snapshot mtimes of all git-tracked files so we can report the
	// real delta from this gen run, not the count of log lines (which
	// is stable across no-op runs per T6).
	mtimesBefore, _ := snapshotMtimes(genCtx)

	// Capture gen output by redirecting stdout
	genOut, err := captureOutput(func() error {
		genCtx.Quiet = false
		return gencmd.RunFullPipeline(genCtx)
	})
	if err != nil {
		return fmt.Errorf("gen: %w", err)
	}

	// Parse gen output
	genLines := parseLines(genOut, regexp.MustCompile(`^. generated ([^\s]+?)/?\s`))

	// Phase 2: lattice BEFORE sync. Lattice writes
	// kernel/spec/lattice/_index.json with sha256 fingerprints; the
	// validation tests run by `bazel test` (inside buildsync.Run)
	// read _index.json and verify it matches actual shard content.
	// If lattice runs in parallel with (or after) buildsync, the
	// tests can see the previous run's stale _index.json and fail
	// with shard sha256 mismatch whenever gen rewrote a shard this
	// pass (e.g., chart_versions.json after an irsa.cue rotation).
	// buildsync only WRITES files outside kernel/spec/lattice/ (see
	// buildsync.go syncOps), so lattice's fingerprint inputs don't
	// depend on buildsync output. AIDR-00127 #1 (mirror fix to the
	// hatch.go runCycle change in the same series).
	latticeCtx := *genCtx
	latticeCtx.Quiet = true
	if latticeErr := lattice.Run(&latticeCtx); latticeErr != nil {
		return fmt.Errorf("lattice: %w", latticeErr)
	}

	syncOut, syncErr := captureOutput(func() error {
		if err := buildsync.Run(genCtx); err != nil {
			return fmt.Errorf("build-sync: %w", err)
		}
		return bulkFormat(genCtx)
	})
	if syncErr != nil {
		return fmt.Errorf("sync: %w", syncErr)
	}
	if msg := lattice.Status(genCtx.WorkDir); msg != "" {
		genCtx.LogOK(msg)
	}

	// Stage all changes
	if err := genCtx.GitAddAll(); err != nil {
		return fmt.Errorf("git add: %w", err)
	}

	// Parse sync output
	syncLines := parseLines(syncOut, regexp.MustCompile(`^. synced: (.+)$`))
	digestCount := countPrefix(syncOut, "\u2713 helm chart ")

	// Write tracking files
	sort.Strings(genLines)
	sort.Strings(syncLines)
	workDir := genCtx.WorkDir
	if _, err := gen.WriteIfChanged(filepath.Join(workDir, "kernel/spec/gen-files.txt"),
		[]byte(strings.Join(genLines, "\n")+"\n"), 0o644); err != nil {
		return fmt.Errorf("write gen-files.txt: %w", err)
	}
	if _, err := gen.WriteIfChanged(filepath.Join(workDir, "kernel/spec/sync-files.txt"),
		[]byte(strings.Join(syncLines, "\n")+"\n"), 0o644); err != nil {
		return fmt.Errorf("write sync-files.txt: %w", err)
	}

	// Report the real delta: files whose mtime advanced between the
	// pre-gen snapshot and now. T1 + T4 guarantee that generators do
	// not bump mtimes on byte-identical writes, so an advanced mtime
	// is a real content change. genLines (log-line count) is kept as
	// a secondary stable figure so gen-files.txt readers can still
	// correlate, but the headline number is the delta.
	changed := countMtimeChanges(genCtx, mtimesBefore)
	if changed == 0 {
		fmt.Printf("\u2713 gen: idempotent (%d outputs tracked)\n", len(genLines))
	} else {
		fmt.Printf("\u2713 gen: %d files changed (%d outputs tracked)\n", changed, len(genLines))
	}
	fmt.Printf("\u2713 sync: %d files synced, %d chart digests\n", len(syncLines), digestCount)

	// Validate images, Bazel coverage, and brick paths in parallel
	var imgErr, bzlErr, brickErr error
	var valWg gosync.WaitGroup
	valWg.Add(3)
	go func() {
		defer valWg.Done()
		imgErr = validate.CheckImages(genCtx)
	}()
	go func() {
		defer valWg.Done()
		bzlErr = validate.CheckBazelCoverage(genCtx)
	}()
	go func() {
		defer valWg.Done()
		brickErr = validate.CheckBricks(genCtx)
	}()
	valWg.Wait()

	if imgErr != nil {
		return fmt.Errorf("check-images: %w", imgErr)
	}
	if bzlErr != nil {
		return fmt.Errorf("check-bazel: %w", bzlErr)
	}
	if brickErr != nil {
		return fmt.Errorf("check-bricks: %w", brickErr)
	}

	return nil
}

func bulkFormat(ctx *gen.Context) error {
	tfOut, err := ctx.Sh("git", "ls-files", "--", "*.tf")
	if err != nil {
		return err
	}
	var tfFiles []string
	for _, f := range strings.Split(tfOut, "\n") {
		if f != "" {
			tfFiles = append(tfFiles, f)
		}
	}
	if len(tfFiles) > 0 {
		args := append([]string{"tofu", "fmt"}, tfFiles...)
		if err := ctx.MiseExec("opentofu", args...); err != nil {
			return fmt.Errorf("tofu fmt: %w", err)
		}
	}
	tvOut, err := ctx.Sh("git", "ls-files", "--", "*.tfvars.json")
	if err != nil {
		return err
	}
	var tvFiles []string
	for _, f := range strings.Split(tvOut, "\n") {
		if f != "" {
			tvFiles = append(tvFiles, f)
		}
	}
	if len(tvFiles) > 0 {
		args := append([]string{"biome", "format", "--write"}, tvFiles...)
		if err := ctx.MiseExec("biome", args...); err != nil {
			return fmt.Errorf("biome format: %w", err)
		}
	}
	return nil
}

// captureOutput delegates to runner.CaptureSilent -- the gen + sync
// phases produce hundreds of per-file "generated <path>" / "synced
// <path>" lines that overwhelm the operator's terminal; we capture
// for parsing (genLines, syncLines counts) but suppress the live
// tee. Final summary lines printed below from the pipeline itself
// are the operator's signal.
// See go/lib/runner/runner.go for capture / silent semantics.
func captureOutput(fn func() error) (string, error) {
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

// snapshotMtimes records the last-modified time of every git-tracked
// file relative to genCtx.WorkDir. Used to compute the real gen delta
// after the pipeline runs. Missing or unreadable files are silently
// omitted -- they will simply appear as "appeared" and contribute to
// the changed count if they exist post-gen.
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

// countMtimeChanges returns the number of files whose mtime advanced
// since the pre-gen snapshot, plus any newly appeared tracked files.
// T1/T3/T4 guarantee generators preserve mtimes on byte-identical
// writes, so an advanced mtime corresponds to a real content change.
func countMtimeChanges(genCtx *gen.Context, before map[string]int64) int {
	if before == nil {
		return 0
	}
	out, err := genCtx.Sh("git", "ls-files")
	if err != nil {
		return 0
	}
	n := 0
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
			n++
		}
	}
	return n
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

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, _ []string) Config { return Config{} }

func RegisterFlags(_ *cobra.Command) {}
