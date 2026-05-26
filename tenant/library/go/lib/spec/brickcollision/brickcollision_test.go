package brickcollision_test

import (
	"encoding/json"
	"fmt"
	"os"
	"testing"

	"github.com/defn/other/m/tenant/library/go/lib/spec/brickcollision"
	"github.com/rogpeppe/go-internal/testscript"
)

// TestMain wires the in-process `brickcollision` command for
// testscript fixtures. Each fixture's `exec brickcollision input.json`
// invokes runCheck against the txtar-supplied input.json.
func TestMain(m *testing.M) {
	os.Exit(testscript.RunMain(m, map[string]func() int{
		"brickcollision": runCheck,
	}))
}

// runCheck reads a JSON file at os.Args[1] containing
// {bricks, brick_io}, runs Check, and prints either "ok" (no
// collisions) or one line per collision via Collision.Format().
// Exits 0 when clean, 1 when collisions are found.
func runCheck() int {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: brickcollision <input.json>")
		return 2
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	var input struct {
		Bricks  map[string]brickcollision.Brick   `json:"bricks"`
		BrickIO map[string]brickcollision.BrickIO `json:"brick_io"`
	}
	if err := json.Unmarshal(data, &input); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	collisions := brickcollision.Check(input.Bricks, input.BrickIO)
	if len(collisions) == 0 {
		fmt.Println("ok")
		return 0
	}
	for _, c := range collisions {
		fmt.Println(c.Format())
	}
	return 1
}

func TestScripts(t *testing.T) {
	testscript.Run(t, testscript.Params{Dir: "testdata"})
}
