#!/usr/bin/env yae
#MISE description = "Build devcontainer base image (infrequent, heavy)"
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

func try(cmd ...string) bool {
	return exec.Command(cmd[0], cmd[1:]...).Run() == nil
}

func gitRoot() string {
	cdup := capture("git", "rev-parse", "--show-cdup")
	if cdup == "" {
		return "."
	}
	return cdup
}

func ghToken() string { return capture("gh", "auth", "token") }

func main() {
	// Guard: uncommitted changes would be silently dropped in the image.
	if status := capture("git", "status", "--porcelain"); status != "" {
		logErr("refusing to rebuild: workspace has uncommitted changes")
		fmt.Println(status)
		fmt.Println("  Fix: commit or stash before running dev-base")
		os.Exit(1)
	}

	// Guard: unpushed commits bake source that collaborators can't reproduce.
	if ahead := capture("git", "rev-list", "--count", "@{upstream}..HEAD"); ahead != "0" {
		branch := capture("git", "rev-parse", "--abbrev-ref", "HEAD")
		logErr("refusing to rebuild: " + ahead + " unpushed commit(s) on " + branch)
		fmt.Println("  Fix: git push")
		os.Exit(1)
	}

	logOk("running mise check")
	run("mise", "run", "check")

	if !try("docker", "image", "inspect", "defn.dev/external/ubuntu:noble") {
		logErr("defn.dev/external/ubuntu:noble not found")
		fmt.Println("  Fix: run 'mise run dev-pull' first")
		os.Exit(1)
	}

	root := gitRoot()
	token := ghToken()
	logOk("building defn.dev/devcontainer/dev:base")
	cmd := exec.Command("docker", "build",
		"--secret", "id=GITHUB_TOKEN,env=GITHUB_TOKEN",
		"-f", root+"/m/kernel/image/docker/base/Dockerfile",
		"-t", "defn.dev/devcontainer/dev:base",
		root)
	cmd.Env = append(os.Environ(), "GITHUB_TOKEN="+token)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	logOk("base image ready")
}
