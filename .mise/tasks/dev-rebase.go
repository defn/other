#!/usr/bin/env yae
#MISE description = "Rebuild base devcontainer + sidecar images, then rebuild edge"
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

func dockerBuild(token, dockerfile, tag, root string) {
	cmd := exec.Command("docker", "build", "-f", dockerfile, "-t", tag, root)
	cmd.Env = append(os.Environ(), "GITHUB_TOKEN="+token)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func main() {
	logOk("pulling external images via Bazel")
	run("mise", "run", "dev-pull")

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

	logOk("building defn.dev/devcontainer/redis")
	dockerBuild(token, root+"/m/kernel/image/docker/redis/Dockerfile", "defn.dev/devcontainer/redis", root)

	logOk("building defn.dev/devcontainer/postgres")
	dockerBuild(token, root+"/m/kernel/image/docker/postgres/Dockerfile", "defn.dev/devcontainer/postgres", root)

	logOk("building defn.dev/devcontainer/bazel-remote")
	dockerBuild(token, root+"/m/kernel/image/docker/bazel-remote/Dockerfile", "defn.dev/devcontainer/bazel-remote", root)

	logOk("building defn.dev/devcontainer/registry")
	dockerBuild(token, root+"/m/kernel/image/docker/registry/Dockerfile", "defn.dev/devcontainer/registry", root)

	logOk("all base images rebuilt")

	logOk("building defn.dev/devcontainer/dev:edge on top of fresh base")
	run("mise", "run", "dev-edge")
}
