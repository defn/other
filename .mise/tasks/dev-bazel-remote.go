#!/usr/bin/env yae
#MISE description = "Build bazel-remote sidecar image"
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

func main() {
	root := gitRoot()
	logOk("building defn.dev/devcontainer/bazel-remote")
	run("docker", "build",
		"-f", root+"/m/kernel/image/docker/bazel-remote/Dockerfile",
		"-t", "defn.dev/devcontainer/bazel-remote",
		root)
	logOk("bazel-remote image ready")
}
