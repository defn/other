#!/usr/bin/env yae
#MISE description = "Remove repo-level git hooks installed by dev-install"
package main

// dev-uninstall -- reverses dev-install. Removes the pre-push hook
// only if it carries our marker; restores any backed-up foreign hook.
// Mirror change in: dev-install.go.

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const hookMarker = "# defn dev-install: pre-push hook (mise run check)"
const backupSuffix = ".bak.defn-install"

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

	data, err := os.ReadFile(hookPath)
	existing := ""
	if err == nil {
		existing = string(data)
	}

	switch {
	case existing == "":
		logOk("no pre-push hook present, nothing to do")

	case !strings.Contains(existing, hookMarker):
		logErr(hookPath + " was not installed by dev-install")
		fmt.Println("  Refusing to delete -- inspect manually.")
		os.Exit(1)

	default:
		if err := os.Remove(hookPath); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		logOk("removed " + hookPath)
		if exists(backup) {
			if err := os.Rename(backup, hookPath); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			os.Chmod(hookPath, 0o755)
			logOk("restored original hook from " + backup)
		}
	}

	logOk("dev-uninstall complete")
}
