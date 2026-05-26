package gen

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// Sh runs a command and returns trimmed stdout. Stderr inherits.
func (c *Context) Sh(args ...string) (string, error) {
	return runner.Output(context.Background(), runner.Opts{
		Args: args,
		Dir:  c.WorkDir,
	})
}

// ShRun runs a command with inherited stdout/stderr.
func (c *Context) ShRun(args ...string) error {
	return runner.Run(context.Background(), runner.Opts{
		Args: args,
		Dir:  c.WorkDir,
	})
}

// MiseBin resolves the absolute path of a tool binary via mise.
func (c *Context) MiseBin(spec, cmdName string) (string, error) {
	parts := strings.SplitN(spec, "@", 2)
	envKey := "MISE_" + strings.ToUpper(parts[0]) + "_VERSION"
	version := ""
	if len(parts) > 1 {
		version = parts[1]
	}
	return runner.Output(context.Background(), runner.Opts{
		Args: []string{"mise", "which", cmdName},
		Dir:  c.WorkDir,
		Env:  append(os.Environ(), envKey+"="+version),
	})
}

// MiseExec runs a tool via mise with inherited IO.
func (c *Context) MiseExec(spec string, args ...string) error {
	bin, err := c.MiseBin(spec, args[0])
	if err != nil {
		return err
	}
	return runner.Run(context.Background(), runner.Opts{
		Args: append([]string{bin}, args[1:]...),
		Dir:  c.WorkDir,
	})
}

// BazelBuild runs bazelisk build via bazel-runner with a normalized environment.
// Blank lines before/after frame Bazel's progress block in the terminal.
// Frame goes to stderr (next to Bazel's own progress) so any stdout-capture
// wrapper on the caller's side doesn't swallow it.
func (c *Context) BazelBuild(targets ...string) error {
	bin := filepath.Join(c.WorkDir, "bin/bazel-runner")
	args := append([]string{bin, "build"}, targets...)
	fmt.Fprintln(os.Stderr)
	defer fmt.Fprintln(os.Stderr)
	return runner.Run(context.Background(), runner.Opts{
		Args: args,
		Dir:  c.WorkDir,
	})
}

// BazelTest runs bazelisk test via bazel-runner with a normalized environment.
// Blank lines before/after frame Bazel's progress block in the terminal.
// Frame goes to stderr (next to Bazel's own progress) so any stdout-capture
// wrapper on the caller's side doesn't swallow it.
func (c *Context) BazelTest(targets ...string) error {
	bin := filepath.Join(c.WorkDir, "bin/bazel-runner")
	args := append([]string{bin, "test", "--test_output=errors"}, targets...)
	fmt.Fprintln(os.Stderr)
	defer fmt.Fprintln(os.Stderr)
	return runner.Run(context.Background(), runner.Opts{
		Args: args,
		Dir:  c.WorkDir,
	})
}

// GitAddAll stages all files.
func (c *Context) GitAddAll() error {
	return c.ShRun("git", "add", "-A")
}

// CueFmt formats CUE files, preserving mtime if content is unchanged.
func (c *Context) CueFmt(files ...string) error {
	// Snapshot mtime + content before formatting
	type snap struct {
		path    string
		content []byte
		modTime time.Time
	}
	var snaps []snap
	for _, f := range files {
		p := filepath.Join(c.WorkDir, f)
		info, err := os.Stat(p)
		if err != nil {
			continue
		}
		data, _ := os.ReadFile(p)
		snaps = append(snaps, snap{p, data, info.ModTime()})
	}

	args := append([]string{"cue", "fmt"}, files...)
	if err := c.MiseExec("cue", args...); err != nil {
		return err
	}

	// Restore mtime if content unchanged (cue fmt rewrites even when no-op)
	for _, s := range snaps {
		after, _ := os.ReadFile(s.path)
		if string(s.content) == string(after) {
			os.Chtimes(s.path, s.modTime, s.modTime)
		}
	}
	return nil
}

// WriteCUEFmtIfChanged writes rawContent to path as cue-fmt-normalized
// content, skipping the write (and preserving mtime) when the on-disk
// file is already byte-identical to what cue fmt would produce. The
// naive sequence of (WriteIfChanged raw -> CueFmt) oscillates because
// the raw content seed generators produce differs from the formatted
// content cue fmt leaves behind, so WriteIfChanged always sees a diff
// and rewrites, bumping mtime on every gen run. This helper formats in
// a tmpfile first, then compares the formatted bytes to the target
// before touching the target.
func (c *Context) WriteCUEFmtIfChanged(path string, rawContent []byte) (changed bool, err error) {
	abs := filepath.Join(c.WorkDir, path)
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		return false, err
	}
	tmp, err := os.CreateTemp(filepath.Dir(abs), ".cuefmt-*.cue")
	if err != nil {
		return false, err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if _, err := tmp.Write(rawContent); err != nil {
		tmp.Close()
		return false, err
	}
	tmp.Close()
	if err := c.MiseExec("cue", "cue", "fmt", tmpPath); err != nil {
		return false, err
	}
	formatted, err := os.ReadFile(tmpPath)
	if err != nil {
		return false, err
	}
	if existing, err := os.ReadFile(abs); err == nil && string(existing) == string(formatted) {
		return false, nil
	}
	return true, os.WriteFile(abs, formatted, 0o644)
}
