#!/usr/bin/env yae
#MISE description = "Fetch all external images into local caches (Docker + OCI registry)"
package main

import (
	"fmt"
	"os"
	"os/exec"
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

func userArgs() []string {
	for i, a := range os.Args {
		if a == "--" {
			return os.Args[i+1:]
		}
	}
	return nil
}

func registryUp() bool {
	return exec.Command("curl", "-sfk", "-o", "/dev/null", "--max-time", "3",
		"https://localhost:5000/v2/").Run() == nil
}

func main() {
	logOk("[1/2] dev-pull -- external images to local Docker")
	run("mise", "run", "dev-pull")

	if registryUp() {
		logOk("[2/2] sync-mirrors -- upstream images to localhost:5000")
		run(append([]string{"mise", "run", "sync-mirrors"}, userArgs()...)...)
		logOk("dev-cache complete")
	} else {
		logErr("[2/2] sync-mirrors SKIPPED -- localhost:5000 not reachable")
		fmt.Println("  To enable: run 'mise run dev-bootstrap' (macOS) or bring")
		fmt.Println("             up the devcontainer compose stack (Linux),")
		fmt.Println("             then re-run 'mise run dev-cache'.")
		logOk("dev-cache complete (partial: dev-pull only)")
	}
}
