package dispatch

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestLanePartition(t *testing.T) {
	cases := []struct {
		name      string
		paths     []string
		brickPath string
		inLane    []string
		outOfLane []string
	}{
		{
			name:      "empty inputs",
			paths:     nil,
			brickPath: "app/foo",
			inLane:    []string{},
			outOfLane: []string{},
		},
		{
			name:      "all in lane",
			paths:     []string{"app/foo/a.cue", "app/foo/sub/b.cue"},
			brickPath: "app/foo",
			inLane:    []string{"app/foo/a.cue", "app/foo/sub/b.cue"},
			outOfLane: []string{},
		},
		{
			name:      "all out of lane",
			paths:     []string{"app/bar/a.cue", "kernel/x.cue"},
			brickPath: "app/foo",
			inLane:    []string{},
			outOfLane: []string{"app/bar/a.cue", "kernel/x.cue"},
		},
		{
			name:      "exact match counts as in-lane",
			paths:     []string{"app/foo"},
			brickPath: "app/foo",
			inLane:    []string{"app/foo"},
			outOfLane: []string{},
		},
		{
			name:      "non-prefix sibling stays out",
			paths:     []string{"app/foo-bar/x.cue"},
			brickPath: "app/foo",
			inLane:    []string{},
			outOfLane: []string{"app/foo-bar/x.cue"},
		},
		{
			name:      "trailing slash on brickPath tolerated",
			paths:     []string{"app/foo/a.cue", "app/bar/b.cue"},
			brickPath: "app/foo/",
			inLane:    []string{"app/foo/a.cue"},
			outOfLane: []string{"app/bar/b.cue"},
		},
		{
			name:      "mixed",
			paths:     []string{"app/foo/a.cue", "kernel/x.cue", "app/foo/sub/b.cue"},
			brickPath: "app/foo",
			inLane:    []string{"app/foo/a.cue", "app/foo/sub/b.cue"},
			outOfLane: []string{"kernel/x.cue"},
		},
		{
			name:      "empty brickPath puts everything out",
			paths:     []string{"a", "b"},
			brickPath: "",
			inLane:    []string{},
			outOfLane: []string{"a", "b"},
		},
		{
			name:      "blank entries skipped",
			paths:     []string{"", "app/foo/x"},
			brickPath: "app/foo",
			inLane:    []string{"app/foo/x"},
			outOfLane: []string{},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			gotIn, gotOut := LanePartition(tc.paths, tc.brickPath)
			if !reflect.DeepEqual(gotIn, tc.inLane) {
				t.Errorf("inLane: want %v, got %v", tc.inLane, gotIn)
			}
			if !reflect.DeepEqual(gotOut, tc.outOfLane) {
				t.Errorf("outOfLane: want %v, got %v", tc.outOfLane, gotOut)
			}
		})
	}
}

// repoFixture builds a small git repo with one commit on main, a
// branch "agent" forked from main with two file edits (one in lane,
// one out of lane). Returns the workspace path, the base SHA, the
// agent branch name, and the brickPath used to partition.
func repoFixture(t *testing.T) (workDir, base, branch, brickPath string) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not on PATH")
	}
	repo := t.TempDir()
	gitEnv := append(os.Environ(),
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=t@t",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=t@t",
	)
	mustGit := func(args ...string) {
		t.Helper()
		cmd := exec.Command("git", args...)
		cmd.Dir = repo
		cmd.Env = gitEnv
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
		}
	}
	mustGit("init", "-q", "-b", "main")
	mustGit("config", "user.email", "t@t")
	mustGit("config", "user.name", "test")
	for _, p := range []string{"app/foo/a.txt", "kernel/x.txt"} {
		full := filepath.Join(repo, p)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte("base\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	mustGit("add", "-A")
	mustGit("commit", "-qm", "init")
	baseOut, err := exec.Command("git", "-C", repo, "rev-parse", "HEAD").Output()
	if err != nil {
		t.Fatal(err)
	}
	base = strings.TrimSpace(string(baseOut))

	// Build the agent branch: in-lane + out-of-lane edit on the
	// same commit so partitioning has work to do.
	mustGit("checkout", "-q", "-b", "agent")
	if err := os.WriteFile(filepath.Join(repo, "app/foo/a.txt"), []byte("base\nin-lane edit\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repo, "kernel/x.txt"), []byte("base\nout-of-lane edit\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	mustGit("add", "-A")
	mustGit("commit", "-qm", "agent edit")
	mustGit("checkout", "-q", "main")

	return repo, base, "agent", "app/foo"
}

func TestLaneDiffAndPartition(t *testing.T) {
	repo, base, branch, brickPath := repoFixture(t)
	ctx := context.Background()

	paths, err := LaneDiff(ctx, repo, base, branch)
	if err != nil {
		t.Fatalf("LaneDiff: %v", err)
	}
	want := map[string]bool{"app/foo/a.txt": true, "kernel/x.txt": true}
	if len(paths) != 2 {
		t.Fatalf("LaneDiff paths: want 2, got %d (%v)", len(paths), paths)
	}
	for _, p := range paths {
		if !want[p] {
			t.Errorf("unexpected diff path %q", p)
		}
	}
	in, out := LanePartition(paths, brickPath)
	if !reflect.DeepEqual(in, []string{"app/foo/a.txt"}) {
		t.Errorf("in-lane: want [app/foo/a.txt], got %v", in)
	}
	if !reflect.DeepEqual(out, []string{"kernel/x.txt"}) {
		t.Errorf("out-of-lane: want [kernel/x.txt], got %v", out)
	}
}

func TestWriteSidecarPatch_AppliesAgainstBase(t *testing.T) {
	repo, base, branch, _ := repoFixture(t)
	ctx := context.Background()
	dest := filepath.Join(repo, ".defn", "dispatch", "test", "out_of_lane", "agent.patch")

	if err := WriteSidecarPatch(ctx, repo, base, branch, []string{"kernel/x.txt"}, dest); err != nil {
		t.Fatalf("WriteSidecarPatch: %v", err)
	}
	if st, err := os.Stat(dest); err != nil || st.Size() == 0 {
		t.Fatalf("sidecar not written: %v size=%d", err, st.Size())
	}

	// Apply the patch in a fresh checkout of base in another worktree.
	checkPath := filepath.Join(repo, ".tmp-apply-check")
	cmd := exec.Command("git", "-C", repo, "worktree", "add", "--detach", checkPath, base)
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=t@t",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=t@t",
	)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("worktree add: %v\n%s", err, out)
	}
	defer func() {
		_ = exec.Command("git", "-C", repo, "worktree", "remove", "--force", checkPath).Run()
	}()
	cmd = exec.Command("git", "-C", checkPath, "apply", "--check", dest)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git apply --check: %v\n%s", err, out)
	}
}

// TestWriteSidecarPatch_ResistantToGitExternalDiff guards against
// regression of the difftastic interception bug found during the
// AIDR-00135 demo: GIT_EXTERNAL_DIFF=difft (set globally by the
// user) intercepted `git diff --binary` and produced a human-
// rendered output that `git apply` could not consume. The sidecar
// must always be a real patch.
func TestWriteSidecarPatch_ResistantToGitExternalDiff(t *testing.T) {
	repo, base, branch, _ := repoFixture(t)
	ctx := context.Background()
	dest := filepath.Join(repo, ".defn", "dispatch", "test", "out_of_lane", "agent.patch")

	// Force the parent environment to advertise an external diff
	// driver. /bin/false will simply exit non-zero; if our
	// scrubbing is incomplete, git invokes it and the patch is
	// either empty or unparseable.
	t.Setenv("GIT_EXTERNAL_DIFF", "/bin/false")

	if err := WriteSidecarPatch(ctx, repo, base, branch, []string{"kernel/x.txt"}, dest); err != nil {
		t.Fatalf("WriteSidecarPatch: %v", err)
	}
	data, err := os.ReadFile(dest)
	if err != nil {
		t.Fatalf("read sidecar: %v", err)
	}
	if !strings.HasPrefix(string(data), "diff --git ") {
		t.Fatalf("sidecar did not start with `diff --git ` -- external diff not scrubbed; got first 80B:\n%q", string(data[:min(80, len(data))]))
	}

	// Apply against fresh base checkout.
	checkPath := filepath.Join(repo, ".tmp-apply-check-2")
	cmd := exec.Command("git", "-C", repo, "worktree", "add", "--detach", checkPath, base)
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=t@t",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=t@t",
	)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("worktree add: %v\n%s", err, out)
	}
	defer func() {
		_ = exec.Command("git", "-C", repo, "worktree", "remove", "--force", checkPath).Run()
	}()
	if out, err := exec.Command("git", "-C", checkPath, "apply", "--check", dest).CombinedOutput(); err != nil {
		t.Fatalf("git apply --check: %v\n%s", err, out)
	}
}

func TestMergeAndRevert_LeavesOnlyInLane(t *testing.T) {
	repo, base, branch, brickPath := repoFixture(t)
	ctx := context.Background()

	mergeWT, err := CreateMergeWorktree(ctx, repo, "test-run", "agent--foo", base)
	if err != nil {
		t.Fatalf("CreateMergeWorktree: %v", err)
	}
	defer func() {
		_ = RemoveWorktree(ctx, repo, mergeWT)
	}()
	// Configure committer in the merge worktree (mustGit on the
	// outer repo set [user] in .git/config; the worktree shares that
	// config but env overrides keep this hermetic).
	for _, args := range [][]string{
		{"-C", mergeWT.Path, "config", "user.email", "t@t"},
		{"-C", mergeWT.Path, "config", "user.name", "test"},
	} {
		if out, err := exec.Command("git", args...).CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}

	paths, err := LaneDiff(ctx, repo, base, branch)
	if err != nil {
		t.Fatalf("LaneDiff: %v", err)
	}
	_, outOfLane := LanePartition(paths, brickPath)

	if err := MergeAndRevert(ctx, mergeWT, branch, outOfLane); err != nil {
		t.Fatalf("MergeAndRevert: %v", err)
	}

	got, err := os.ReadFile(filepath.Join(mergeWT.Path, "app/foo/a.txt"))
	if err != nil {
		t.Fatalf("read in-lane: %v", err)
	}
	if !strings.Contains(string(got), "in-lane edit") {
		t.Errorf("in-lane edit missing from merge tree: %q", got)
	}
	got, err = os.ReadFile(filepath.Join(mergeWT.Path, "kernel/x.txt"))
	if err != nil {
		t.Fatalf("read out-of-lane: %v", err)
	}
	if strings.Contains(string(got), "out-of-lane edit") {
		t.Errorf("out-of-lane edit leaked into merge tree: %q", got)
	}

	// Status should be clean -- the commit closed it.
	out, err := exec.Command("git", "-C", mergeWT.Path, "status", "--porcelain").Output()
	if err != nil {
		t.Fatalf("status: %v", err)
	}
	if strings.TrimSpace(string(out)) != "" {
		t.Errorf("merge worktree dirty after MergeAndRevert: %q", out)
	}
}
