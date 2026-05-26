#!/usr/bin/env yae
#MISE description = "Build devcontainer edge image (frequent, incremental)"
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func logOk(msg string) { fmt.Println("✓ " + msg) }

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

func gitRoot() string {
	cdup := capture("git", "rev-parse", "--show-cdup")
	if cdup == "" {
		return "."
	}
	return cdup
}

func ghToken() string { return capture("gh", "auth", "token") }

func main() {
	root := gitRoot()
	token := ghToken()
	commit := capture("git", "rev-parse", "HEAD")
	logOk("building defn.dev/devcontainer/dev:edge @ " + commit)
	cmd := exec.Command("docker", "build",
		"--secret", "id=GITHUB_TOKEN,env=GITHUB_TOKEN",
		"--build-arg", "GIT_COMMIT="+commit,
		"-f", root+"/m/kernel/image/docker/edge/Dockerfile",
		"-t", "defn.dev/devcontainer/dev:edge",
		root)
	cmd.Env = append(os.Environ(), "GITHUB_TOKEN="+token)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	logOk("edge image ready")
}
