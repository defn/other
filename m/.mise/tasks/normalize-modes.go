#!/usr/bin/env yae
#MISE description = "Normalize file modes for tracked text-source files to 0644 (idempotent)"
package main

// normalize-modes -- chmod 0644 every git-tracked file matching the
// text-source file patterns below. Idempotent: chmod is a no-op on
// files already at 0644.
//
// Why: tools that emit tracked files (tofu's local_file, openssl
// cert-gen, ad-hoc operator edits) default to umask-derived modes
// (0600 / 0700) that don't match the brick manifest's _#reg = 0644
// expectation. Manifest validation catches the drift but doesn't
// auto-fix; this task is the auto-fix. AIDR-00127 #7.
//
// Wired into `mise run check`'s sentinel block so operator workflow
// never has to remember to chmod.
//
// Skip list (intentionally executable):
//   .mise/tasks/*.clj  (babashka tasks, 0755)
//   .mise/tasks/*.go   (yae tasks, 0755)
//   bin/*              (entry-point scripts, 0755)

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

var textGlobs = []string{
	"*.pem", "*.cue", "*.md", "*.yaml", "*.yml", "*.json", "*.toml",
	"*.txt", "*.tf", "*.go", "*.bzl", "*.bazel", "BUILD.bazel",
}

func skip(path string) bool {
	return strings.HasPrefix(path, ".mise/tasks/") ||
		strings.HasPrefix(path, "m/bin/") ||
		strings.HasPrefix(path, "bin/") ||
		strings.HasSuffix(path, ".sh")
}

func main() {
	args := append([]string{"ls-files", "--"}, textGlobs...)
	out, err := exec.Command("git", args...).Output()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	var candidates []string
	for _, line := range strings.Split(string(out), "\n") {
		if line != "" && !skip(line) {
			candidates = append(candidates, line)
		}
	}

	if len(candidates) > 0 {
		cmd := exec.Command("xargs", "chmod", "0644")
		cmd.Stdin = strings.NewReader(strings.Join(candidates, "\n"))
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}

	fmt.Printf("✓ normalize-modes: chmod 0644 applied to %d tracked text-source files\n", len(candidates))
}
