#!/usr/bin/env yae
#MISE description = "Pull latest source from /workspace and rebuild edge image"
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func logOk(msg string)  { fmt.Println("✓ " + msg) }
func logErr(msg string) { fmt.Fprintln(os.Stderr, "✗ "+msg) }

func run(cmd ...string) {
	c := exec.Command(cmd[0], cmd[1:]...)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	if err := c.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func capture(cmd ...string) string {
	out, err := exec.Command(cmd[0], cmd[1:]...).Output()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	return strings.TrimSpace(string(out))
}

func main() {
	// Guard: uncommitted changes would be silently dropped in the image.
	if status := capture("git", "status", "--porcelain"); status != "" {
		logErr("refusing to rebuild: workspace has uncommitted changes")
		fmt.Println(status)
		fmt.Println("  Fix: commit or stash before running dev-sync")
		os.Exit(1)
	}

	if ahead := capture("git", "rev-list", "--count", "@{upstream}..HEAD"); ahead != "0" {
		branch := capture("git", "rev-parse", "--abbrev-ref", "HEAD")
		logErr("refusing to rebuild: " + ahead + " unpushed commit(s) on " + branch)
		fmt.Println("  Fix: git push")
		os.Exit(1)
	}

	logOk("running mise check")
	run("mise", "run", "check")

	logOk("trusting /workspace/mise.toml")
	run("mise", "trust", "/workspace/mise.toml")

	logOk("pulling latest in /workspace")
	cmd := exec.Command("git", "-c", "safe.directory=/workspace", "pull")
	cmd.Dir = "/workspace"
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	run("mise", "run", "dev-edge")
	run("mise", "run", "dev-push")
	logOk("dev-sync complete -- rebuild container from VS Code to pick up changes")
}
