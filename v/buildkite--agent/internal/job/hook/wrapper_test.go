package hook_test

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/defn/other/m/v/buildkite--agent/env"
	"github.com/defn/other/m/v/buildkite--agent/internal/job/hook"
	"github.com/defn/other/m/v/buildkite--agent/internal/shell"
	"github.com/defn/other/m/v/buildkite--agent/internal/tempfile"
	"gotest.tools/v3/assert"
)

type hookTestCase struct {
	name, os, hook string
}

func TestRunningHookDetectsChangedEnvironment(t *testing.T) {
	t.Parallel()

	testCases := []hookTestCase{
		{
			name: "hook",
			os:   "linux",
			hook: `#!/bin/sh
export LLAMAS=rock
export Alpacas='are ok'
echo hello world
`,
		},
		{
			name: "hook.sh",
			os:   "linux",
			hook: `#!/bin/sh
export LLAMAS=rock
export Alpacas='are ok'
echo hello world
`,
		},
	}

	if runtime.GOOS == "windows" {
		testCases = append(testCases,
			hookTestCase{
				name: "hook.bat",
				os:   "windows",
				hook: `@echo off
set LLAMAS=rock
set Alpacas=are ok
echo hello world
`,
			},
			hookTestCase{
				name: "hook.ps1",
				os:   "windows",
				hook: `$env:LLAMAS = "rock"
$env:Alpacas = "are ok"
echo "hello world"
`,
			},
		)
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			ctx := context.Background()

			hookFilename := writeTestHook(t, tc.name, tc.hook)
			wrapper, err := hook.NewWrapper(hook.WithPath(hookFilename), hook.WithOS(tc.os))
			assert.NilError(t, err, "failed to create hook wrapper: %v", err)

			sh := shell.NewTestShell(t)

			script, err := sh.Script(wrapper.Path(), "")
			if err != nil {
				t.Fatalf("sh.Script(%q) = %v", wrapper.Path(), err)
			}
			runScriptWithRetry(t, script, ctx)

			changes, err := wrapper.Changes()
			assert.NilError(t, err, "wrapper.Changes() = %v", err)

			// Windows’ batch 'SET >' normalises environment variables case so we apply
			// the 'expected' and 'actual' diffs to a blank Environment which handles
			// case normalisation for us
			expected := env.New()
			expected.Apply(env.Diff{
				Added: map[string]string{
					"LLAMAS":  "rock",
					"Alpacas": "are ok",
				},
				Changed: map[string]env.DiffPair{},
				Removed: map[string]struct{}{},
			})

			actual := env.New()
			actual.Apply(changes.Diff)

			// The strict equals check here also ensures we aren't bubbling up the
			// internal BUILDKITE_HOOK_EXIT_STATUS and BUILDKITE_HOOK_WORKING_DIR
			// environment variables
			assert.DeepEqual(t, expected.Dump(), actual.Dump())
		})
	}
}

func TestRunningHookDetectsChangedWorkingDirectory(t *testing.T) {
	t.Parallel()

	testCases := []hookTestCase{
		{
			name: "hook",
			os:   "linux",
			hook: `#!/bin/sh
mkdir changed-working-dir
cd changed-working-dir
echo hello world
`,
		},
		{
			name: "hook.sh",
			os:   "linux",
			hook: `#!/bin/sh
mkdir changed-working-dir
cd changed-working-dir
echo hello world
`,
		},
	}

	if runtime.GOOS == "windows" {
		testCases = []hookTestCase{
			{
				name: "hook.bat",
				os:   "windows",
				hook: `@echo off
mkdir changed-working-dir
cd changed-working-dir
echo hello world
`,
			},
			{
				name: "hook.ps1",
				os:   "windows",
				hook: `mkdir changed-working-dir
cd changed-working-dir
echo hello world
`,
			},
		}
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			ctx := context.Background()

			hookFilename := writeTestHook(t, tc.name, tc.hook)
			wrapper, err := hook.NewWrapper(hook.WithPath(hookFilename), hook.WithOS(tc.os))
			assert.NilError(t, err, "failed to create hook wrapper: %v", err)

			sh := shell.NewTestShell(t)

			hookWorkingDir, err := os.MkdirTemp("", "test-hook-working-dir")
			assert.NilError(t, err, `os.MkdirTemp("", "test-hook-working-dir") error = %v`, err)

			err = sh.Chdir(hookWorkingDir)
			assert.NilError(t, err, "sh.Chdir(%q) = %v", hookWorkingDir, err)

			script, err := sh.Script(wrapper.Path(), "")
			if err != nil {
				t.Fatalf("sh.Script(%q) = %v", wrapper.Path(), err)
			}
			runScriptWithRetry(t, script, ctx)

			changes, err := wrapper.Changes()
			assert.NilError(t, err, "wrapper.Changes() = %v", err)

			absWorkingDir := filepath.Join(hookWorkingDir, "changed-working-dir")

			expectedWorkingDir, err := filepath.EvalSymlinks(absWorkingDir)
			assert.NilError(t, err, "filepath.EvalSymlinks(%q) error = %v", absWorkingDir, err)

			afterWd, err := changes.GetAfterWd()
			assert.NilError(t, err, "changes.GetAfterWd() = %v", err)

			actualWorkingDir, err := filepath.EvalSymlinks(afterWd)
			assert.NilError(t, err, "filepath.EvalSymlinks(%q) error = %v", afterWd, err)

			assert.Equal(t, expectedWorkingDir, actualWorkingDir)
		})
	}
}

func TestScriptWrapperFailsOnHookWithInvalidShebang(t *testing.T) {
	t.Parallel()

	hookFilename := writeTestHook(t, "hook", "#!/usr/bin/env python3\nprint('hello world')")

	_, err := hook.NewWrapper(
		hook.WithPath(hookFilename),
		hook.WithOS("linux"),
	)
	assert.Error(t, err, `scriptwrapper tried to wrap hook with invalid shebang: "#!/usr/bin/env python3"`)
}

func writeTestHook(t *testing.T, fileName, content string) string {
	t.Helper()

	tempFile, err := tempfile.New(
		tempfile.WithName(fileName),
		tempfile.KeepingExtension(),
		tempfile.WithPerms(0o700),
	)
	assert.NilError(t, err, "failed to create temp file with name %q", fileName)

	t.Cleanup(func() {
		if tempFile == nil {
			return
		}

		cerr := tempFile.Close()
		if !errors.Is(cerr, os.ErrClosed) {
			assert.Check(t, cerr == nil, "failed to close temp file %q: %v", tempFile.Name(), cerr)
		}

		rerr := os.Remove(tempFile.Name())
		assert.Check(t, rerr == nil, "failed to remove temp file %q: %v", tempFile.Name(), rerr)
	})

	_, err = io.WriteString(tempFile, content)
	assert.NilError(t, err, "failed to write to temp file %q", tempFile.Name())

	err = tempFile.Close()
	assert.NilError(t, err, "failed to close temp file %q", tempFile.Name())

	return tempFile.Name()
}

// runScriptWithRetry retries on ETXTBSY which can occur when parallel tests
// exec script files concurrently on Linux.
func runScriptWithRetry(t *testing.T, script shell.Command, ctx context.Context) {
	t.Helper()
	for range 5 {
		err := script.Run(ctx, shell.ShowPrompt(false))
		if err == nil {
			return
		}
		if !strings.Contains(err.Error(), "text file busy") {
			t.Fatalf("script.Run() = %v", err)
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("script.Run() failed after retries: text file busy")
}
