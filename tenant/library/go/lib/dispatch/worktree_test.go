package dispatch

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// TestWorktreeLifecycle creates a temp git repo, spawns a worktree
// via CreateWorktree, makes a commit inside it, merges back via
// MergeWorktree, and verifies the agent's edit landed on the
// coordinator's HEAD before RemoveWorktree tears everything down.
//
// Mirrors the F2 isolation contract end-to-end on a sandbox repo so
// the assertion doesn't depend on the parent repo's state.
func TestWorktreeLifecycle(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not on PATH")
	}
	repo := t.TempDir()
	mustGit := func(args ...string) {
		t.Helper()
		cmd := exec.Command("git", args...)
		cmd.Dir = repo
		cmd.Env = append(os.Environ(),
			"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=t@t",
			"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=t@t",
		)
		out, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
		}
	}
	mustGit("init", "-q", "-b", "main")
	mustGit("config", "user.email", "t@t")
	mustGit("config", "user.name", "test")
	if err := os.WriteFile(filepath.Join(repo, "tracked.txt"), []byte("base\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	mustGit("add", "tracked.txt")
	mustGit("commit", "-qm", "init")

	ctx := context.Background()
	wt, err := CreateWorktree(ctx, repo, "test-run", "agent-a")
	if err != nil {
		t.Fatalf("CreateWorktree: %v", err)
	}
	if _, err := os.Stat(wt.Path); err != nil {
		t.Fatalf("worktree path missing: %v", err)
	}

	// Agent edits a tracked file inside its worktree, commits.
	agentFile := filepath.Join(wt.AgentWorkDir, "tracked.txt")
	if err := os.WriteFile(agentFile, []byte("base\nagent-edit\n"), 0o644); err != nil {
		t.Fatalf("agent edit: %v", err)
	}
	for _, args := range [][]string{
		{"-C", wt.Path, "add", "tracked.txt"},
		{"-C", wt.Path, "-c", "user.email=t@t", "-c", "user.name=test", "commit", "-qm", "agent commit"},
	} {
		cmd := exec.Command("git", args...)
		cmd.Env = append(os.Environ(),
			"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=t@t",
			"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=t@t",
		)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("agent git %v: %v\n%s", args, err, out)
		}
	}

	// Coordinator merges agent's branch back.
	if err := MergeWorktree(ctx, repo, wt); err != nil {
		t.Fatalf("MergeWorktree: %v", err)
	}

	// The edit should now exist on the coordinator's tracked file.
	got, err := os.ReadFile(filepath.Join(repo, "tracked.txt"))
	if err != nil {
		t.Fatalf("read coord file: %v", err)
	}
	if !strings.Contains(string(got), "agent-edit") {
		t.Fatalf("merge missed the agent edit; got %q", string(got))
	}

	// Cleanup removes the worktree dir + agent branch.
	if err := RemoveWorktree(ctx, repo, wt); err != nil {
		t.Fatalf("RemoveWorktree: %v", err)
	}
	if _, err := os.Stat(wt.Path); !os.IsNotExist(err) {
		t.Fatalf("worktree path still exists after remove: %v", err)
	}
	out, err := exec.Command("git", "-C", repo, "branch", "--list", wt.Branch).Output()
	if err != nil {
		t.Fatalf("git branch --list: %v", err)
	}
	if strings.TrimSpace(string(out)) != "" {
		t.Fatalf("agent branch still present: %q", string(out))
	}
}

// TestWorktreeLifecycle_NoCommitMergeIsNoOp covers the common case
// where the agent runs CycleBrick (read-only today) and exits
// without any commits. MergeWorktree must return nil and leave HEAD
// unchanged.
func TestWorktreeLifecycle_NoCommitMergeIsNoOp(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not on PATH")
	}
	repo := t.TempDir()
	mustGit := func(args ...string) {
		t.Helper()
		cmd := exec.Command("git", args...)
		cmd.Dir = repo
		cmd.Env = append(os.Environ(),
			"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=t@t",
			"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=t@t",
		)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
		}
	}
	mustGit("init", "-q", "-b", "main")
	mustGit("config", "user.email", "t@t")
	mustGit("config", "user.name", "test")
	if err := os.WriteFile(filepath.Join(repo, "f"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	mustGit("add", "f")
	mustGit("commit", "-qm", "init")

	ctx := context.Background()
	headBefore, err := exec.Command("git", "-C", repo, "rev-parse", "HEAD").Output()
	if err != nil {
		t.Fatal(err)
	}

	wt, err := CreateWorktree(ctx, repo, "test", "noop")
	if err != nil {
		t.Fatalf("CreateWorktree: %v", err)
	}
	defer RemoveWorktree(ctx, repo, wt)

	// Don't commit anything. Merge should be a no-op.
	if err := MergeWorktree(ctx, repo, wt); err != nil {
		t.Fatalf("MergeWorktree: %v", err)
	}

	headAfter, err := exec.Command("git", "-C", repo, "rev-parse", "HEAD").Output()
	if err != nil {
		t.Fatal(err)
	}
	if string(headBefore) != string(headAfter) {
		t.Fatalf("HEAD moved during no-op merge: before=%s after=%s", headBefore, headAfter)
	}
}
