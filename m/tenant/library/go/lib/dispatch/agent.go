package dispatch

import (
	"context"
	"fmt"
	"os/exec"

	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// autoCommitWorktree stages every change in the worktree and
// creates one commit so MergeWorktree has something to bring back.
// No-op when the agent left the tree clean -- common when the
// agent just observed / read.
//
// No agent-side lane policing: workers commit everything they
// touch and trust the coordinator to reconcile out-of-lane work
// mechanically (TODO 1a). The previous --strict-lanes contract
// (refuse + force-delete branch) silently discarded paid-for
// prompts on every false positive; we removed it 2026-05-09 in
// favor of "workers commit everything; coordinator decides."
func autoCommitWorktree(ctx context.Context, workDir, slug string) error {
	cmd := exec.CommandContext(ctx, "git", "status", "-z", "--porcelain")
	cmd.Dir = workDir
	raw, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("agent: git status: %w", err)
	}
	if len(raw) == 0 {
		return nil
	}
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "add", "-A"},
		Dir:  workDir,
	}); err != nil {
		return fmt.Errorf("agent: git add: %w", err)
	}
	msg := fmt.Sprintf("agent %s: dispatched edits", slug)
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "commit", "-qm", msg},
		Dir:  workDir,
	}); err != nil {
		return fmt.Errorf("agent: git commit: %w", err)
	}
	return nil
}
