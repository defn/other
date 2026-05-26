package brickreads_test

import (
	"encoding/json"
	"fmt"
	"os"
	"testing"

	"github.com/defn/other/m/tenant/library/go/lib/spec/brickreads"
	"github.com/rogpeppe/go-internal/testscript"
)

// TestMain wires the in-process `brickreads` command for testscript
// fixtures. Each fixture's `exec brickreads input.json` invokes
// runDiff against the txtar-supplied input.json.
func TestMain(m *testing.M) {
	os.Exit(testscript.RunMain(m, map[string]func() int{
		"brickreads": runDiff,
	}))
}

// runDiff reads a JSON file at os.Args[1] containing
// {bricks, brick_io}, runs Diff, and prints either "ok" (no
// staleness) or one line per Stale finding via Stale.Format().
// Exits 0 when clean, 1 when staleness is found.
func runDiff() int {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: brickreads <input.json>")
		return 2
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	var input struct {
		Bricks  map[string]brickreads.Brick   `json:"bricks"`
		BrickIO map[string]brickreads.BrickIO `json:"brick_io"`
	}
	if err := json.Unmarshal(data, &input); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	stale := brickreads.Diff(input.Bricks, input.BrickIO)
	if len(stale) == 0 {
		fmt.Println("ok")
		return 0
	}
	for _, s := range stale {
		fmt.Println(s.Format())
	}
	return 1
}

func TestScripts(t *testing.T) {
	testscript.Run(t, testscript.Params{Dir: "testdata"})
}
