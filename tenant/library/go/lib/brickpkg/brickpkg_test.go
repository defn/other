package brickpkg

import (
	"os"
	"path/filepath"
	"testing"
)

// AIDR-00132 OQ7 step 2 / AIDR-00136: tests for the per-brick
// package-name detection (subproblem A: reuse existing dir-local
// package) and stub-derivation (subproblem B: synthesize from path).
// IsCueModPath is also covered here -- it travels with the same
// detection logic and is consumed by every caller of DetectPackage.

func TestDetectPackage_PicksUpExistingCUEPackage(t *testing.T) {
	dir := t.TempDir()
	must(t, os.WriteFile(filepath.Join(dir, "things.cue"),
		[]byte("@experiment()\n\npackage foo\n\nx: 1\n"), 0o644))
	got, err := DetectPackage(dir, "tenant/library/app/foo")
	if err != nil {
		t.Fatalf("DetectPackage: %v", err)
	}
	if got != "foo" {
		t.Errorf("got %q, want %q", got, "foo")
	}
}

func TestDetectPackage_IgnoresSelfDispatchCUE(t *testing.T) {
	// DetectPackage must skip dispatch.cue itself so re-runs are
	// idempotent. If the dir has only dispatch.cue (e.g. a prior
	// run wrote a stub), fall back to the path-derived stub rather
	// than reading dispatch.cue's stub package and locking it in.
	dir := t.TempDir()
	must(t, os.WriteFile(filepath.Join(dir, DispatchFile),
		[]byte("package somethingelse\n"), 0o644))
	got, err := DetectPackage(dir, "bin")
	if err != nil {
		t.Fatalf("DetectPackage: %v", err)
	}
	if got != "bin" {
		t.Errorf("got %q, want stub %q derived from path", got, "bin")
	}
}

func TestDetectPackage_NoCUEFiles_StubFromBase(t *testing.T) {
	dir := t.TempDir()
	got, err := DetectPackage(dir, "bin")
	if err != nil {
		t.Fatalf("DetectPackage: %v", err)
	}
	if got != "bin" {
		t.Errorf("got %q, want %q", got, "bin")
	}
}

func TestStubPackageName(t *testing.T) {
	cases := []struct {
		path string
		want string
	}{
		{"bin", "bin"},
		{"aidr", "aidr"},
		{"tenant/library/app/foo", "foo"},
		{".devcontainer", "devcontainer"}, // leading dot stripped
		{".mise/tasks", "tasks"},          // last segment
		{"gen/.mise/tasks", "tasks"},      // collision is fine
		{"go/cmd/root", "root"},
		{"some-thing", "some_thing"},  // hyphen sanitized
		{"some.thing", "some_thing"},  // dot mid-segment sanitized
		{"123leading", "_123leading"}, // digit-prefix gets underscore
		{".", "stub"},                 // pathological dot-only
	}
	for _, tc := range cases {
		t.Run(tc.path, func(t *testing.T) {
			got := StubPackageName(tc.path)
			if got != tc.want {
				t.Errorf("StubPackageName(%q) = %q, want %q", tc.path, got, tc.want)
			}
		})
	}
}

func TestIsCueModPath(t *testing.T) {
	cases := []struct {
		path string
		want bool
	}{
		{"cue.mod", true},
		{"cue.mod/module.cue", true},
		{"cue.mod/pkg/x/y", true},
		{"", false},
		{"cue.mod.bak", false}, // prefix match must be path-bounded
		{"foo/cue.mod", false}, // only top-level cue.mod is the special dir
		{"aidr", false},
	}
	for _, tc := range cases {
		t.Run(tc.path, func(t *testing.T) {
			if got := IsCueModPath(tc.path); got != tc.want {
				t.Errorf("IsCueModPath(%q) = %v, want %v", tc.path, got, tc.want)
			}
		})
	}
}

func TestReadWorkerIO_Default(t *testing.T) {
	dir := t.TempDir()
	must(t, os.WriteFile(filepath.Join(dir, "dispatch.cue"),
		[]byte(`@experiment()

package x

import "github.com/defn/other/kernel/spec/dispatch"

worker: dispatch.#BrickResult & {
	reads: []
	writes: []
}
`), 0o644))
	reads, writes, ok, err := ReadWorkerIO(dir)
	if err != nil {
		t.Fatalf("ReadWorkerIO: %v", err)
	}
	if !ok {
		t.Fatal("expected ok=true")
	}
	if len(reads) != 0 || len(writes) != 0 {
		t.Errorf("reads=%v writes=%v, expected both empty", reads, writes)
	}
}

func TestReadWorkerIO_NonEmpty(t *testing.T) {
	dir := t.TempDir()
	must(t, os.WriteFile(filepath.Join(dir, "dispatch.cue"),
		[]byte(`@experiment()
package x
import "github.com/defn/other/kernel/spec/dispatch"
worker: dispatch.#BrickResult & {
	reads: ["foo", "bar/baz"]
	writes: [
		"out/one.txt",
		"out/two.txt",
	]
}
`), 0o644))
	reads, writes, ok, err := ReadWorkerIO(dir)
	if err != nil {
		t.Fatalf("ReadWorkerIO: %v", err)
	}
	if !ok {
		t.Fatal("expected ok=true")
	}
	wantReads := []string{"foo", "bar/baz"}
	wantWrites := []string{"out/one.txt", "out/two.txt"}
	if !equalSlice(reads, wantReads) {
		t.Errorf("reads=%v, want %v", reads, wantReads)
	}
	if !equalSlice(writes, wantWrites) {
		t.Errorf("writes=%v, want %v", writes, wantWrites)
	}
}

func TestReadWorkerIO_Missing(t *testing.T) {
	dir := t.TempDir()
	reads, writes, ok, err := ReadWorkerIO(dir)
	if err != nil {
		t.Fatalf("ReadWorkerIO: %v", err)
	}
	if ok {
		t.Error("expected ok=false for missing dispatch.cue")
	}
	if reads != nil || writes != nil {
		t.Errorf("expected nil slices, got reads=%v writes=%v", reads, writes)
	}
}

func equalSlice(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}
