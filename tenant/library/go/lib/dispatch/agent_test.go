package dispatch

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// TestAutoCommitWorktree covers the two cases the stripped-down
// post-strict-lanes autoCommitWorktree must distinguish:
//   - clean tree: no commit, HEAD unchanged;
//   - dirty tree: commit, HEAD advances by one.
//
// No agent-side lane policing -- the coordinator reconciles
// out-of-lane work mechanically (TODO 1a).
func TestAutoCommitWorktree(t *testing.T) {
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
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	mustGit("init", "-q", "-b", "main")
	mustGit("config", "user.email", "t@t")
	mustGit("config", "user.name", "test")
	full := filepath.Join(repo, "tenant/library/app/foo")
	if err := os.MkdirAll(full, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(full, "f.cue"), []byte("init\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	mustGit("add", "-A")
	mustGit("commit", "-qm", "init")

	ctx := context.Background()

	t.Run("clean_tree_no_commit", func(t *testing.T) {
		headBefore := revParseHEAD(t, repo)
		if err := autoCommitWorktree(ctx, repo, "app--foo"); err != nil {
			t.Fatal(err)
		}
		if h := revParseHEAD(t, repo); h != headBefore {
			t.Fatalf("clean tree advanced HEAD: before=%s after=%s", headBefore, h)
		}
	})

	t.Run("dirty_tree_commits", func(t *testing.T) {
		headBefore := revParseHEAD(t, repo)
		writeFile(t, repo, "tenant/library/app/foo/f.cue", "edit\n")
		if err := autoCommitWorktree(ctx, repo, "app--foo"); err != nil {
			t.Fatal(err)
		}
		if h := revParseHEAD(t, repo); h == headBefore {
			t.Fatalf("dirty tree did not advance HEAD: %s", h)
		}
	})
}

func writeFile(t *testing.T, root, rel, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(root, rel), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func revParseHEAD(t *testing.T, repo string) string {
	t.Helper()
	out, err := exec.Command("git", "-C", repo, "rev-parse", "HEAD").Output()
	if err != nil {
		t.Fatalf("rev-parse: %v", err)
	}
	return strings.TrimSpace(string(out))
}
