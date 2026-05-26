#!/usr/bin/env yae
#MISE description = "Push devcontainer edge image to local registry"
package main

import (
	"fmt"
	"os"
	"os/exec"
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

func main() {
	src := "defn.dev/devcontainer/dev:edge"
	dst := "localhost:5000/devcontainer/dev:edge"
	logOk("tagging " + src + " -> " + dst)
	run("docker", "tag", src, dst)
	logOk("pushing " + dst)
	run("docker", "push", dst)
	logOk("dev-push complete")
}
