// Coord-side lane reconciliation for `defn dispatch` (AIDR-00135).
//
// Workers commit everything; the coordinator reconciles mechanically.
// After an agent finishes its worktree, the coordinator partitions
// the agent's diff against the lane (brick path), writes any
// out-of-lane edits as a sidecar patch the operator can apply
// elsewhere, and merges only the in-lane portion via a merge-and-
// revert dance in a temp worktree branched from the current coord
// HEAD. The result is that out-of-lane spillage never lands on the
// coord branch but is preserved verbatim for human judgment.
//
// AIDR-00098's brick-collision invariant guarantees disjoint write
// prefixes across bricks, which is what makes the sequential
// merge-and-revert path safe (no cross-agent in-lane conflicts).

package dispatch

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// gitPlainEnv returns the parent environment with GIT_EXTERNAL_DIFF
// and related diff-format overrides removed. Some users set
// GIT_EXTERNAL_DIFF=difft (difftastic) globally for interactive
// review; that intercepts every `git diff --binary` and produces a
// human-prettified rendering instead of a real applyable patch.
// Sidecar generation MUST get the raw, machine-readable patch.
func gitPlainEnv() []string {
	skip := map[string]struct{}{
		"GIT_EXTERNAL_DIFF": {},
		"GIT_DIFF_OPTS":     {},
		"GIT_PAGER":         {},
	}
	src := os.Environ()
	out := make([]string, 0, len(src))
	for _, kv := range src {
		eq := strings.IndexByte(kv, '=')
		if eq < 0 {
			out = append(out, kv)
			continue
		}
		if _, drop := skip[kv[:eq]]; drop {
			continue
		}
		out = append(out, kv)
	}
	return out
}

// LanePartition splits diffPaths into in-lane (prefix-matches
// brickPath) and out-of-lane sets. brickPath is workspace-relative
// (matching the shape git emits with `--relative`). An empty
// brickPath returns everything as out-of-lane: a brick must declare
// a lane to claim anything.
//
// Both result slices are sorted for deterministic downstream
// behavior. A nil input yields two empty (non-nil) slices.
func LanePartition(diffPaths []string, brickPath string) (inLane, outOfLane []string) {
	inLane = []string{}
	outOfLane = []string{}
	if len(diffPaths) == 0 {
		return
	}
	bp := strings.TrimSuffix(brickPath, "/")
	for _, p := range diffPaths {
		if p == "" {
			continue
		}
		if bp != "" && (p == bp || strings.HasPrefix(p, bp+"/")) {
			inLane = append(inLane, p)
			continue
		}
		outOfLane = append(outOfLane, p)
	}
	sort.Strings(inLane)
	sort.Strings(outOfLane)
	return
}

// LaneDiff returns the workspace-relative paths git reports as
// changed between base..branch when run from workDir. Uses
// --relative so the output shape matches brickPath (workspace-
// relative) without further string arithmetic on the coord side.
func LaneDiff(ctx context.Context, workDir, base, branch string) ([]string, error) {
	out, err := runner.Output(ctx, runner.Opts{
		Args: []string{"git", "diff", "--name-only", "--relative", base + ".." + branch},
		Dir:  workDir,
	})
	if err != nil {
		return nil, fmt.Errorf("lane diff %s..%s: %w", base, branch, err)
	}
	if strings.TrimSpace(out) == "" {
		return nil, nil
	}
	lines := strings.Split(out, "\n")
	paths := make([]string, 0, len(lines))
	for _, l := range lines {
		l = strings.TrimSpace(l)
		if l != "" {
			paths = append(paths, l)
		}
	}
	return paths, nil
}

// WriteSidecarPatch captures `git diff --binary base..branch -- paths`
// from workDir and writes it to dest. dest is created with parent
// directories. The patch is anchored at base (a stable named
// commit), so the operator can apply it later via
// `git apply --3way` against any coord state.
//
// Returns an error if the diff is empty -- callers should only
// invoke this when LanePartition reported a non-empty out-of-lane
// set.
func WriteSidecarPatch(ctx context.Context, workDir, base, branch string, paths []string, dest string) error {
	if len(paths) == 0 {
		return fmt.Errorf("sidecar: no out-of-lane paths to write")
	}
	// gitPlainEnv neutralizes GIT_EXTERNAL_DIFF (set globally by
	// users running difftastic for interactive review). Without
	// scrubbing, `git diff --binary` is intercepted and produces a
	// human-rendered output that `git apply` cannot consume.
	args := []string{"git", "diff", "--binary", base + ".." + branch, "--"}
	args = append(args, paths...)
	out, err := runner.Output(ctx, runner.Opts{
		Args: args,
		Dir:  workDir,
		Env:  gitPlainEnv(),
	})
	if err != nil {
		return fmt.Errorf("sidecar diff: %w", err)
	}
	if strings.TrimSpace(out) == "" {
		return fmt.Errorf("sidecar: git diff produced no output for %d paths", len(paths))
	}
	if dir := filepath.Dir(dest); dir != "." && dir != "" {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return fmt.Errorf("sidecar: mkdir %s: %w", dir, err)
		}
	}
	// runner.Output trims trailing whitespace; restore the trailing
	// newline so `git apply` sees a well-formed patch.
	if !strings.HasSuffix(out, "\n") {
		out += "\n"
	}
	if err := os.WriteFile(dest, []byte(out), 0o644); err != nil {
		return fmt.Errorf("sidecar: write %s: %w", dest, err)
	}
	return nil
}

// MergeAndRevert performs the in-lane merge dance inside the merge
// worktree:
//
//  1. `git merge --no-commit --no-ff <agentBranch>` -- a real
//     three-way merge against coord HEAD so any prior in-lane
//     state integrates correctly with the agent's edits.
//  2. `git restore --source=HEAD --staged --worktree -- <outOfLane>`
//     -- reset out-of-lane paths in both index and worktree to
//     coord HEAD content. After this, only in-lane paths remain
//     staged.
//  3. `git commit -m ...` -- a single merge commit holding the
//     integrated in-lane state.
//
// The coordinator merges the resulting branch back via the existing
// `MergeWorktree` primitive in a separate step.
//
// On any failure mid-dance the caller should retain the merge
// worktree for inspection (AIDR-00135 Q4 cleanup policy).
func MergeAndRevert(ctx context.Context, mergeWT *Worktree, agentBranch string, outOfLane []string) error {
	if mergeWT == nil {
		return fmt.Errorf("merge-and-revert: nil worktree")
	}
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "merge", "--no-commit", "--no-ff", agentBranch},
		Dir:  mergeWT.Path,
	}); err != nil {
		return fmt.Errorf("merge-and-revert: merge %s: %w", agentBranch, err)
	}
	if len(outOfLane) > 0 {
		args := []string{"git", "restore", "--source=HEAD", "--staged", "--worktree", "--"}
		args = append(args, outOfLane...)
		if err := runner.Run(ctx, runner.Opts{
			Args: args,
			Dir:  mergeWT.Path,
		}); err != nil {
			return fmt.Errorf("merge-and-revert: restore out-of-lane: %w", err)
		}
		// Verify the restore actually neutralized the out-of-lane
		// paths; if any still appear in `git status --porcelain`
		// we are in an inconsistent state and must abort.
		status, err := runner.Output(ctx, runner.Opts{
			Args: []string{"git", "status", "--porcelain", "-z", "--"},
			Dir:  mergeWT.Path,
		})
		if err != nil {
			return fmt.Errorf("merge-and-revert: status check: %w", err)
		}
		ool := map[string]struct{}{}
		for _, p := range outOfLane {
			ool[p] = struct{}{}
		}
		for _, entry := range strings.Split(status, "\x00") {
			if len(entry) < 4 {
				continue
			}
			path := entry[3:]
			if _, hit := ool[path]; hit {
				return fmt.Errorf("merge-and-revert: out-of-lane path %q still dirty after restore", path)
			}
		}
	}
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "commit", "-m", fmt.Sprintf("agent %s: in-lane merge (out-of-lane pruned)", mergeWT.Slug)},
		Dir:  mergeWT.Path,
	}); err != nil {
		return fmt.Errorf("merge-and-revert: commit: %w", err)
	}
	return nil
}
