package runner_test

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// helperEnv selects the helper-process role. The TestHelperProcess test
// reads it and runs the requested behavior, then exits. When unset, the
// test is a no-op so `go test` of the package skips it.
const helperEnv = "DEFN_RUNNER_TEST_HELPER"

// TestHelperProcess is invoked as a subprocess by the runner tests via
// re-exec of the test binary. It checks helperEnv to decide what to do.
// This is the standard os/exec helper-process pattern, hermetic to the
// package -- no external commands required.
func TestHelperProcess(t *testing.T) {
	role := os.Getenv(helperEnv)
	if role == "" {
		return
	}
	defer os.Exit(0)
	switch role {
	case "spew-1mb":
		// Write 1 MiB to stdout in 4 KiB chunks. Without Capture's
		// concurrent pipe drainer the writer would block at 64 KiB and
		// the parent test would time out.
		chunk := bytes.Repeat([]byte("x"), 4096)
		for i := 0; i < 256; i++ {
			if _, err := os.Stdout.Write(chunk); err != nil {
				os.Exit(2)
			}
		}
	case "echo-stdout":
		fmt.Fprint(os.Stdout, os.Getenv("HELPER_TEXT"))
	case "echo-stderr":
		fmt.Fprint(os.Stderr, os.Getenv("HELPER_TEXT"))
	case "exit-code":
		os.Exit(7)
	case "print-cwd":
		dir, _ := os.Getwd()
		fmt.Fprint(os.Stdout, dir)
	case "print-env":
		fmt.Fprint(os.Stdout, os.Getenv("HELPER_PROBE"))
	default:
		os.Exit(99)
	}
}

// helperArgs returns the argv to re-exec the test binary in helper mode,
// running only TestHelperProcess.
func helperArgs() []string {
	return []string{os.Args[0], "-test.run=^TestHelperProcess$"}
}

// helperEnvWith returns os.Environ() augmented with helperEnv=role and
// any extra KEY=VAL pairs.
func helperEnvWith(role string, extra ...string) []string {
	env := append([]string{}, os.Environ()...)
	env = append(env, helperEnv+"="+role)
	env = append(env, extra...)
	return env
}

// withDeadline runs fn and fails the test if it doesn't return within d.
// The deadlock-prevention test relies on this: with the bug, fn would
// block indefinitely; with the fix, it returns in well under a second.
func withDeadline(t *testing.T, d time.Duration, fn func() error) error {
	t.Helper()
	done := make(chan error, 1)
	go func() { done <- fn() }()
	select {
	case err := <-done:
		return err
	case <-time.After(d):
		t.Fatalf("operation did not complete within %s -- likely a stdout pipe deadlock", d)
		return nil // unreachable
	}
}

func TestCapture_GoStdout(t *testing.T) {
	got, err := runner.Capture(func() error {
		fmt.Println("hello from go")
		return nil
	})
	if err != nil {
		t.Fatalf("Capture: %v", err)
	}
	if !strings.Contains(got, "hello from go") {
		t.Fatalf("captured output missing expected line: %q", got)
	}
}

func TestCapture_FnErrorPropagated(t *testing.T) {
	want := fmt.Errorf("boom")
	_, err := runner.Capture(func() error { return want })
	if err == nil || err.Error() != "boom" {
		t.Fatalf("expected boom, got %v", err)
	}
}

func TestCapture_SubprocessInheritsStdout(t *testing.T) {
	got, err := runner.Capture(func() error {
		return runner.Run(context.Background(), runner.Opts{
			Args: helperArgs(),
			Env:  helperEnvWith("echo-stdout", "HELPER_TEXT=spawned-child"),
		})
	})
	if err != nil {
		t.Fatalf("Capture/Run: %v", err)
	}
	if !strings.Contains(got, "spawned-child") {
		t.Fatalf("captured output missing subprocess stdout: %q", got)
	}
}

// TestCapture_StallPrevention is the regression test for the 64 KiB
// pipe-buffer deadlock. The helper writes 1 MiB to stdout, which is
// 16x the pipe buffer. With the bug (read-after-fn), the helper would
// block writing and the parent would never reach the post-fn drain
// loop, hanging forever. With the fix (concurrent drainer goroutine),
// it completes immediately. We bound the entire operation at 10s so
// a regression turns into a fast test failure rather than a hung CI.
func TestCapture_StallPrevention(t *testing.T) {
	const want = 256 * 4096 // 1 MiB
	var captured string
	err := withDeadline(t, 10*time.Second, func() error {
		got, capErr := runner.Capture(func() error {
			return runner.Run(context.Background(), runner.Opts{
				Args: helperArgs(),
				Env:  helperEnvWith("spew-1mb"),
			})
		})
		captured = got
		return capErr
	})
	if err != nil {
		t.Fatalf("Capture/Run: %v", err)
	}
	// The captured buffer also contains test framework noise (e.g.
	// "PASS\nok ..." from the helper's own `go test` epilogue). The
	// invariant under test is that all 1 MiB of helper-emitted bytes
	// made it through, so check >= want, not equality.
	if len(captured) < want {
		t.Fatalf("captured %d bytes; want >= %d (drainer dropped data?)", len(captured), want)
	}
}

func TestRun_Success(t *testing.T) {
	err := runner.Run(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("echo-stdout", "HELPER_TEXT=ok"),
		Stdout: &bytes.Buffer{}, // discard
		Stderr: &bytes.Buffer{},
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
}

func TestRun_NonzeroExit(t *testing.T) {
	err := runner.Run(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("exit-code"),
		Stdout: &bytes.Buffer{},
		Stderr: &bytes.Buffer{},
	})
	if err == nil {
		t.Fatalf("expected error from exit 7, got nil")
	}
}

func TestRun_StdoutCapturedToWriter(t *testing.T) {
	var out bytes.Buffer
	err := runner.Run(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("echo-stdout", "HELPER_TEXT=routed"),
		Stdout: &out,
		Stderr: &bytes.Buffer{},
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if !strings.Contains(out.String(), "routed") {
		t.Fatalf("Stdout writer missing data: %q", out.String())
	}
}

func TestRun_StderrCapturedToWriter(t *testing.T) {
	var errBuf bytes.Buffer
	err := runner.Run(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("echo-stderr", "HELPER_TEXT=via-stderr"),
		Stdout: &bytes.Buffer{},
		Stderr: &errBuf,
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if !strings.Contains(errBuf.String(), "via-stderr") {
		t.Fatalf("Stderr writer missing data: %q", errBuf.String())
	}
}

func TestRun_DirHonored(t *testing.T) {
	dir := t.TempDir()
	var out bytes.Buffer
	err := runner.Run(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("print-cwd"),
		Dir:    dir,
		Stdout: &out,
		Stderr: &bytes.Buffer{},
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	// On macOS /tmp is symlinked to /private/tmp; the child's getwd
	// follows the symlink. Compare via suffix match on the leaf name.
	if !strings.Contains(out.String(), dir) && !strings.HasSuffix(strings.TrimSpace(out.String()), strings.TrimPrefix(dir, "/private")) {
		t.Fatalf("expected cwd %q, got %q", dir, out.String())
	}
}

func TestRun_EnvOverride(t *testing.T) {
	var out bytes.Buffer
	err := runner.Run(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("print-env", "HELPER_PROBE=visible"),
		Stdout: &out,
		Stderr: &bytes.Buffer{},
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if !strings.Contains(out.String(), "visible") {
		t.Fatalf("env not propagated: %q", out.String())
	}
}

func TestRun_EmptyArgsRejected(t *testing.T) {
	err := runner.Run(context.Background(), runner.Opts{Args: nil})
	if err == nil {
		t.Fatalf("expected error for empty Args")
	}
}

func TestRun_ContextCancelStopsChild(t *testing.T) {
	// Cancelled context should cause Run to return promptly with a
	// non-nil error. Bounded by withDeadline so a regression that
	// loses context wiring turns into a test failure, not a hang.
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := withDeadline(t, 5*time.Second, func() error {
		return runner.Run(ctx, runner.Opts{
			Args:   helperArgs(),
			Env:    helperEnvWith("echo-stdout", "HELPER_TEXT=irrelevant"),
			Stdout: &bytes.Buffer{},
			Stderr: &bytes.Buffer{},
		})
	})
	if err == nil {
		t.Fatalf("expected error from cancelled context")
	}
}

func TestStart_RunsThenWaits(t *testing.T) {
	var out bytes.Buffer
	cmd, err := runner.Start(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("echo-stdout", "HELPER_TEXT=started"),
		Stdout: &out,
		Stderr: &bytes.Buffer{},
	})
	if err != nil {
		t.Fatalf("Start: %v", err)
	}
	if err := cmd.Wait(); err != nil {
		t.Fatalf("Wait: %v", err)
	}
	if !strings.Contains(out.String(), "started") {
		t.Fatalf("background output missing: %q", out.String())
	}
}

func TestStart_KillTerminatesChild(t *testing.T) {
	cmd, err := runner.Start(context.Background(), runner.Opts{
		Args:   []string{"sleep", "60"},
		Stdout: &bytes.Buffer{},
		Stderr: &bytes.Buffer{},
	})
	if err != nil {
		t.Skipf("sleep not available: %v", err)
	}
	if err := cmd.Process.Kill(); err != nil {
		t.Fatalf("Kill: %v", err)
	}
	// Wait should return promptly with a non-nil error after Kill.
	err = withDeadline(t, 5*time.Second, cmd.Wait)
	if err == nil {
		t.Fatalf("expected Wait to return error after Kill")
	}
}

func TestOutput_TrimmedStdout(t *testing.T) {
	got, err := runner.Output(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("echo-stdout", "HELPER_TEXT=  padded\n\n"),
		Stderr: &bytes.Buffer{},
	})
	if err != nil {
		t.Fatalf("Output: %v", err)
	}
	if got != "padded" {
		t.Fatalf("expected trimmed %q, got %q", "padded", got)
	}
}

func TestOutput_NonzeroExit(t *testing.T) {
	_, err := runner.Output(context.Background(), runner.Opts{
		Args:   helperArgs(),
		Env:    helperEnvWith("exit-code"),
		Stderr: &bytes.Buffer{},
	})
	if err == nil {
		t.Fatalf("expected error from exit 7, got nil")
	}
}
