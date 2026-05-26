package dispatch

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// Worktree captures the lifecycle of one agent's git worktree.
// Each entry corresponds to a `git worktree add -b <branch> <path>
// HEAD` invocation: a separate checkout on its own branch, branched
// from the coordinator's current HEAD. The agent runs entirely
// inside AgentWorkDir; commits land on Branch; the coordinator
// merges Branch back into the run-time HEAD at the end.
type Worktree struct {
	Slug         string // brick slug the agent is working on
	Path         string // absolute path to the worktree's root (git toplevel inside)
	AgentWorkDir string // absolute path to the workspace inside the worktree (Path + "/m" if defn lives in a subdir)
	Branch       string // refs/heads/<branch>
	Base         string // commit SHA the worktree forked from
}

// CreateWorktree spawns a worktree at workDir/.defn/dispatch/<run>/wt/<slug>
// branched off HEAD. Returns the *Worktree handle the caller passes
// to MergeWorktree / RemoveWorktree.
//
// When the defn workspace lives in a subdirectory of the git
// toplevel (e.g. `m/` inside the larger repo), AgentWorkDir is the
// equivalent subdirectory inside the new worktree. The agent's
// CycleBrick invocation uses that path so its findWorkspaceRoot
// resolves correctly.
func CreateWorktree(ctx context.Context, workDir, runID, slug string) (*Worktree, error) {
	return createWorktreeAt(ctx, workDir, runID, slug, "wt", "dispatch", "HEAD")
}

// CreateMergeWorktree spawns a sibling worktree under merge/<slug>
// branched from an explicit fork-point SHA (typically the coord
// branch's HEAD at merge time). Used by the lane-reconciliation
// merge-and-revert dance (AIDR-00135) to integrate an agent's in-
// lane edits without touching the coord checkout.
//
// fromSHA must be a resolvable git revision; passing the result of
// `git rev-parse HEAD` from the coord workspace is the load-bearing
// shape (sequential merge semantics: each wave sees prior waves).
func CreateMergeWorktree(ctx context.Context, workDir, runID, slug, fromSHA string) (*Worktree, error) {
	if strings.TrimSpace(fromSHA) == "" {
		return nil, fmt.Errorf("merge worktree: empty fromSHA")
	}
	return createWorktreeAt(ctx, workDir, runID, slug, "merge", "merge", fromSHA)
}

// createWorktreeAt is the shared implementation of CreateWorktree
// and CreateMergeWorktree. subdir is the layout slot under
// .defn/dispatch/<run>/ ("wt" or "merge"); branchPrefix is the first
// path segment of the branch ref ("dispatch" or "merge"); fromRev is
// the git revision to fork from.
func createWorktreeAt(ctx context.Context, workDir, runID, slug, subdir, branchPrefix, fromRev string) (*Worktree, error) {
	// Canonicalize the workspace path so filepath.Rel against
	// git's realpath toplevel works. macOS's /var -> /private/var
	// symlink would otherwise produce a "../../" relative path.
	workDir, err := filepath.EvalSymlinks(workDir)
	if err != nil {
		return nil, fmt.Errorf("worktree: canonicalize workdir: %w", err)
	}
	base, err := runner.Output(ctx, runner.Opts{
		Args: []string{"git", "rev-parse", fromRev},
		Dir:  workDir,
	})
	if err != nil {
		return nil, fmt.Errorf("worktree: resolve %s: %w", fromRev, err)
	}
	toplevel, err := runner.Output(ctx, runner.Opts{
		Args: []string{"git", "rev-parse", "--show-toplevel"},
		Dir:  workDir,
	})
	if err != nil {
		return nil, fmt.Errorf("worktree: resolve toplevel: %w", err)
	}
	relWorkDir, err := filepath.Rel(toplevel, workDir)
	if err != nil {
		return nil, fmt.Errorf("worktree: relpath %s under %s: %w", workDir, toplevel, err)
	}
	branch := fmt.Sprintf("%s/%s/%s", branchPrefix, runID, slug)
	wtPath := filepath.Join(workDir, ".defn", "dispatch", runID, subdir, slug)
	if err := os.MkdirAll(filepath.Dir(wtPath), 0o755); err != nil {
		return nil, fmt.Errorf("worktree: mkdir parent: %w", err)
	}
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "worktree", "add", "-b", branch, wtPath, base},
		Dir:  workDir,
	}); err != nil {
		return nil, fmt.Errorf("worktree: add %s: %w", wtPath, err)
	}
	agentWD := filepath.Join(wtPath, relWorkDir)

	// Mise refuses to load tool config from un-trusted paths -- a
	// fresh worktree is a new path even though every config file
	// is byte-identical to the parent's. Trust the worktree's
	// mise configs so any process that resolves a mise shim (e.g.
	// the ACP bridge) can find the underlying tool. Best-effort:
	// don't fail worktree creation if `mise trust` errors.
	//
	// Multiple mise configs are searchable from the worktree:
	//   <wt>/mise.toml                     (outer repo top-level)
	//   <wt>/<rel>/mise.toml               (defn workspace top-level)
	//   <wt>/.config/mise/config.toml      (XDG, often a symlink)
	//   <wt>/<rel>/root/.config/mise/config.toml  (the [tools] file)
	// Trust whichever exist.
	candidates := []string{
		filepath.Join(wtPath, "mise.toml"),
		filepath.Join(agentWD, "mise.toml"),
		filepath.Join(wtPath, ".config", "mise", "config.toml"),
		filepath.Join(agentWD, "root", ".config", "mise", "config.toml"),
	}
	for _, p := range candidates {
		if _, err := os.Lstat(p); err != nil {
			continue
		}
		_ = runner.Run(ctx, runner.Opts{
			Args: []string{"mise", "trust", "--quiet", p},
			Dir:  workDir,
		})
	}

	return &Worktree{
		Slug:         slug,
		Path:         wtPath,
		AgentWorkDir: agentWD,
		Branch:       branch,
		Base:         base,
	}, nil
}

// MergeWorktree merges the agent's branch back into the coordinator's
// HEAD. Uses --no-ff so the agent commit (if any) shows up as a
// distinct merge in the history. If the agent made no commits, the
// merge is a no-op (already at the same SHA as HEAD).
func MergeWorktree(ctx context.Context, workDir string, wt *Worktree) error {
	// Check if the agent advanced its branch beyond Base.
	cur, err := runner.Output(ctx, runner.Opts{
		Args: []string{"git", "rev-parse", wt.Branch},
		Dir:  workDir,
	})
	if err != nil {
		return fmt.Errorf("worktree: resolve %s: %w", wt.Branch, err)
	}
	if strings.TrimSpace(cur) == strings.TrimSpace(wt.Base) {
		// Agent made no commits. Nothing to merge.
		return nil
	}
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "merge", "--no-ff", "--no-edit", wt.Branch},
		Dir:  workDir,
	}); err != nil {
		return fmt.Errorf("worktree: merge %s: %w", wt.Branch, err)
	}
	return nil
}

// RemoveWorktree tears down the worktree directory and deletes the
// agent branch. Force-flagged because we don't care about saving
// the worktree state -- if the agent had commits, MergeWorktree
// already brought them onto HEAD.
func RemoveWorktree(ctx context.Context, workDir string, wt *Worktree) error {
	var firstErr error
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "worktree", "remove", "--force", wt.Path},
		Dir:  workDir,
	}); err != nil {
		firstErr = fmt.Errorf("worktree: remove %s: %w", wt.Path, err)
	}
	// Branch -D succeeds even after a merge (idempotent on already-
	// merged branches via -D / force-delete).
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "branch", "-D", wt.Branch},
		Dir:  workDir,
	}); err != nil && firstErr == nil {
		firstErr = fmt.Errorf("worktree: delete branch %s: %w", wt.Branch, err)
	}
	return firstErr
}
