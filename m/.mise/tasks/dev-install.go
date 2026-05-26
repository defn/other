#!/usr/bin/env yae
#MISE description = "Install repo-level git hooks (pre-push -> mise run check)"
package main

// dev-install -- installs hooks that should run on every push from
// this clone. Idempotent: re-running is a no-op if the hook is already ours.
// If a foreign pre-push hook is present, backs it up and chains through it.
// Mirror change in: dev-uninstall.go.

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const hookMarker = "# defn dev-install: pre-push hook (mise run check)"
const backupSuffix = ".bak.defn-install"

const hookScript = `#!/usr/bin/env bash
# defn dev-install: pre-push hook (mise run check)
set -euo pipefail

# Forward stdin/args to any pre-existing pre-push hook backed up by
# dev-install (commit-signing wrapper, lint, etc.).
HOOK_DIR="$(dirname "$0")"
ORIG="$HOOK_DIR/$(basename "$0")` + backupSuffix + `"
if [ -x "$ORIG" ]; then
  "$ORIG" "$@"
fi

# Run repo-level checks. cd into the Bazel workspace so mise run
# picks up m/mise.toml regardless of where git push was invoked.
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT/m"
mise run check
echo >&2
`

func logOk(msg string)  { fmt.Println("✓ " + msg) }
func logErr(msg string) { fmt.Fprintln(os.Stderr, "✗ "+msg) }

func capture(cmd ...string) string {
	out, err := exec.Command(cmd[0], cmd[1:]...).Output()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	return strings.TrimSpace(string(out))
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func main() {
	hooksDir := capture("git", "rev-parse", "--git-path", "hooks")
	hookPath := hooksDir + "/pre-push"
	backup := hookPath + backupSuffix

	existing := ""
	if data, err := os.ReadFile(hookPath); err == nil {
		existing = string(data)
	}

	switch {
	case existing != "" && strings.Contains(existing, hookMarker):
		// Already ours -- refresh content.
		if err := os.WriteFile(hookPath, []byte(hookScript), 0o755); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		logOk("pre-push hook refreshed at " + hookPath)

	case existing != "" && !exists(backup):
		// Foreign hook, no backup yet -- back it up then install.
		if err := os.Rename(hookPath, backup); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		os.Chmod(backup, 0o755)
		if err := os.WriteFile(hookPath, []byte(hookScript), 0o755); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		logOk("backed up existing hook to " + backup)
		logOk("installed pre-push hook at " + hookPath)

	case existing != "" && exists(backup):
		// Foreign hook AND backup already exists -- refuse.
		logErr(hookPath + " is foreign and " + backup + " already exists -- refusing to overwrite")
		fmt.Println("  Fix: inspect both files; if the backup is stale,")
		fmt.Println("       delete it and re-run mise run dev-install.")
		os.Exit(1)

	default:
		// No existing hook -- clean install.
		if err := os.WriteFile(hookPath, []byte(hookScript), 0o755); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		logOk("installed pre-push hook at " + hookPath)
	}

	logOk("dev-install complete")
}
