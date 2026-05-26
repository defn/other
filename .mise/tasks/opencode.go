#!/usr/bin/env yae
#MISE description = "Run OpenCode CLI"
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
	cmd := exec.Command("opencode", userArgs()...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		os.Exit(1)
	}
}
