#!/usr/bin/env yae
#MISE description = "Run Claude Code CLI with skip permissions"
package main

import (
	"os"
	"os/exec"
)

func userArgs() []string {
	for i, a := range os.Args {
		if a == "--" {
			return os.Args[i+1:]
		}
	}
	return nil
}

func main() {
	args := append([]string{
		"--dangerously-skip-permissions",
		"--append-system-prompt", "IMPORTANT: When creating git commits, do NOT include any authorship attribution lines in the commit message body. Authorship is already captured in git commit metadata.",
	}, userArgs()...)
	cmd := exec.Command("claude", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		os.Exit(1)
	}
}
