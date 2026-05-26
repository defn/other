// Command artifact-fs is the only binary entrypoint for the artifact-fs
// project. It mounts Git repositories as a merged, writable FUSE filesystem.
//
// Repo shape:
//
//   - cmd/artifact-fs   -- the only binary entrypoint (this file).
//   - internal/cli      -- wires commands onto daemon.Service.
//   - internal/daemon   -- owns repo lifecycle (registry sync, snapshot publish, overlay reconcile, FUSE mount, watcher, refresh loop).
//   - internal/fusefs   -- the merged view and writable filesystem layer.
//   - internal/gitstore -- performance-sensitive git wrapper; most easy-to-break invariants live there.
//   - internal/snapshot -- persistent SQLite-backed snapshot store.
//   - internal/overlay  -- persistent SQLite-backed overlay store.
//   - internal/model    -- canonical types, interfaces, and path/name normalization used across packages.
//
// Non-obvious CLI/runtime behavior:
//
//   - ARTIFACT_FS_ROOT is the state root. `artifact-fs daemon --root` is
//     the mount root. They are different things.
//   - `add-repo` is one-shot: register repo, clone blobless, build the
//     initial snapshot, then exit. It does not mount FUSE or start
//     background goroutines.
//   - `daemon` is long-running: it mounts registered repos and starts
//     the watcher, refresh, and hydrator workers.
//
// Testing and environment quirks:
//
//   - macOS e2e coverage needs macFUSE. Linux e2e needs /dev/fuse.
//   - Tests live next to code, but bench_test.go, e2e_test.go,
//     e2e_git_test.go, and e2e_bench_test.go are in the root package.
//   - Benchmarks are opt-in: AFS_RUN_BENCH=1 go test -run TestBenchRepos -v
//   - FUSE e2e tests are opt-in: AFS_RUN_E2E_TESTS=1 go test -run TestE2E -v .
//   - E2E tests default to a local bare repo. Set AFS_E2E_REPO only when
//     you intentionally want a real remote.
//   - E2E benchmark coverage: AFS_RUN_E2E_BENCH=1 go test -run TestE2EBenchmarkRepos -v .
//
// CI / dev loop:
//
//	go build ./cmd/artifact-fs
//	go vet ./...
//	go test ./...
//
// Follow that order for non-trivial changes.
//
// Conventions worth preserving (also noted in the relevant packages):
//
//   - fusefs: Readdir() stays thin; merged directory logic belongs in
//     ReaddirTyped().
//   - watcher: polls HEAD plus the current HEAD ref path. If you change
//     it, preserve branch-switch and packed-ref behavior covered by
//     internal/watcher/watcher_test.go.
//   - overlay: stores deletes as SQLite entries with kind='delete';
//     there is no on-disk whiteout file layer.
//   - meta: SQLite is modernc.org/sqlite in WAL mode via internal/meta.
package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/defn/other/m/v/cloudflare--artifact-fs/internal/cli"
)

// main keeps CLI wiring separate from the testable command implementation.
func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()
	os.Exit(cli.Run(ctx, os.Args[1:], os.Stdout, os.Stderr))
}
