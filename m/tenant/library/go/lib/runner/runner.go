// Package runner is the single owner of the OS-process / stdout-capture
// boundary. Every "run a child process" or "capture stdout into a string"
// call in the codebase should go through here so a fix to a tricky boundary
// condition (pipe-buffer deadlocks, stderr framing, signal propagation,
// env passthrough) lands in exactly one place instead of regressing across
// N hand-rolled inline copies.
//
// History: a 64 KiB pipe-buffer deadlock in the previous duplicated
// CaptureOutput implementations (pipeline.captureOutput, hatch.CaptureOutput)
// caused intermittent stalls in `mise run check` whenever bazel test wrote
// enough to stdout to fill the pipe before the post-fn drainer ran. The fix
// (concurrent drainer goroutine + live tee to the original stdout) lives here
// in Capture; do not re-implement.
//
// TODO: longer-term, eliminate the os.Stdout mutation in Capture by
// plumbing a writer through gen.Context (so RunFullPipeline / buildsync.Run
// write to ctx.Out instead of fmt.Println'ing global stdout). That removes
// the global-state hack entirely. Tracked separately; not in scope for the
// initial consolidation.
package runner

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
)

// Opts controls a single subprocess invocation. Defaults match the
// historical hand-rolled shapes (Stdout/Stderr inherit, no env override)
// so callers migrating from inline exec.Command don't change behavior.
type Opts struct {
	// Args is the command and its arguments. Args[0] is the executable.
	Args []string

	// Dir is the working directory for the child. Empty = inherit.
	Dir string

	// Env, when non-nil, replaces the child's environment entirely.
	// Use os.Environ() as a base if you only mean to add variables.
	Env []string

	// Stdout / Stderr override the inherited streams. Nil means inherit
	// (os.Stdout / os.Stderr). To capture into a buffer, pass it here;
	// the runner does NOT pipe to a *os.File without a drainer (that
	// shape is the bug this package exists to prevent).
	Stdout io.Writer
	Stderr io.Writer

	// Stdin, when non-nil, is wired to the child's stdin.
	Stdin io.Reader
}

// buildCmd constructs an *exec.Cmd from Opts with Stdout/Stderr defaulting
// to inherit. Shared by Run and Start.
func buildCmd(ctx context.Context, opts Opts) *exec.Cmd {
	cmd := exec.CommandContext(ctx, opts.Args[0], opts.Args[1:]...)
	cmd.Dir = opts.Dir
	cmd.Env = opts.Env
	cmd.Stdin = opts.Stdin
	if opts.Stdout != nil {
		cmd.Stdout = opts.Stdout
	} else {
		cmd.Stdout = os.Stdout
	}
	if opts.Stderr != nil {
		cmd.Stderr = opts.Stderr
	} else {
		cmd.Stderr = os.Stderr
	}
	return cmd
}

// Run runs a subprocess to completion. Stdout / Stderr inherit by default.
// Caller-supplied io.Writer destinations are safe (the runner does not
// substitute a pipe behind the scenes).
func Run(ctx context.Context, opts Opts) error {
	if len(opts.Args) == 0 {
		return fmt.Errorf("runner: empty Args")
	}
	cmd := buildCmd(ctx, opts)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%s: %w", opts.Args[0], err)
	}
	return nil
}

// Start launches a subprocess and returns the running *exec.Cmd. Callers
// are responsible for calling Wait() or Process.Kill() on the returned cmd.
// Use this for background / long-running processes (e.g. a streaming
// kubectl watch); use Run for foreground "execute and wait" calls.
//
// *exec.Cmd is leaked deliberately: it is the stdlib's standard handle for
// "process I might Wait or Kill," and wrapping it adds no value. The runner
// still owns the construction (Stdout/Stderr defaults, env, dir) so the
// boundary remains in one place.
func Start(ctx context.Context, opts Opts) (*exec.Cmd, error) {
	if len(opts.Args) == 0 {
		return nil, fmt.Errorf("runner: empty Args")
	}
	cmd := buildCmd(ctx, opts)
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("%s: %w", opts.Args[0], err)
	}
	return cmd, nil
}

// Output runs a subprocess and returns its trimmed stdout.
// Stderr inherits by default; pass opts.Stderr to override.
// Stdin / Stdout overrides on opts are ignored (Stdout is captured).
func Output(ctx context.Context, opts Opts) (string, error) {
	if len(opts.Args) == 0 {
		return "", fmt.Errorf("runner: empty Args")
	}
	cmd := exec.CommandContext(ctx, opts.Args[0], opts.Args[1:]...)
	cmd.Dir = opts.Dir
	cmd.Env = opts.Env
	cmd.Stdin = opts.Stdin
	if opts.Stderr != nil {
		cmd.Stderr = opts.Stderr
	} else {
		cmd.Stderr = os.Stderr
	}
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("%s: %w", opts.Args[0], err)
	}
	return strings.TrimSpace(string(out)), nil
}

// Capture redirects os.Stdout to a pipe, runs fn, and returns everything
// written to stdout while fn ran -- INCLUDING from any subprocess that
// inherits stdout. Output is also live-tee'd to the original stdout so
// terminal users see progress as it happens.
//
// A reader goroutine drains the pipe concurrently with fn(); without it,
// subprocesses (e.g. `bazel test` via gen.Context.BazelTest) deadlock on
// pipe_write once their stdout exceeds the 64 KiB pipe buffer. The
// duplicated hand-rolled versions of this function in pipeline and hatch
// hit exactly that bug; this is the single fix point.
func Capture(fn func() error) (string, error) {
	return capture(fn, true)
}

// CaptureSilent is Capture without the live tee to stdout. The caller
// gets the captured buffer for parsing; the user sees nothing during
// the run. Use this when the long-running phase is too verbose to
// stream and the caller will print a summary at the end.
func CaptureSilent(fn func() error) (string, error) {
	return capture(fn, false)
}

func capture(fn func() error, tee bool) (string, error) {
	r, w, err := os.Pipe()
	if err != nil {
		return "", err
	}
	oldStdout := os.Stdout
	os.Stdout = w

	var buf bytes.Buffer
	done := make(chan struct{})
	go func() {
		if tee {
			_, _ = io.Copy(io.MultiWriter(&buf, oldStdout), r)
		} else {
			_, _ = io.Copy(&buf, r)
		}
		close(done)
	}()

	fnErr := fn()

	w.Close()
	os.Stdout = oldStdout
	<-done
	r.Close()

	return buf.String(), fnErr
}
