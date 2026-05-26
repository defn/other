#!/usr/bin/env yae
#MISE description = "Rebuild edge devcontainer image and launch dev"
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

	logOk("building defn.dev/devcontainer/dev:edge")
	cmd := exec.Command("docker", "build",
		"--secret", "id=GITHUB_TOKEN,env=GITHUB_TOKEN",
		"-f", root+"/m/kernel/image/docker/edge/Dockerfile",
		"-t", "defn.dev/devcontainer/dev:edge",
		root)
	cmd.Env = append(os.Environ(), "GITHUB_TOKEN="+token)
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Print(string(out))
		logErr("edge image build failed")
		s := string(out)
		if strings.Contains(s, "pipx") || strings.Contains(s, "No such file or directory") || strings.Contains(s, "Failed to install") {
			fmt.Println()
			logErr("base image appears stale -- missing tools needed by edge")
			fmt.Println("  Fix: run 'mise run dev-rebase' to rebuild base, then edge")
		}
		os.Exit(1)
	}
	fmt.Print(string(out))

	logOk("edge image rebuilt, launching dev")
	run("mise", "run", "dev")
}
