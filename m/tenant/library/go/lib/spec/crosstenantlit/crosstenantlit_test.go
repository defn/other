package crosstenantlit_test

import (
	"encoding/json"
	"fmt"
	"os"
	"testing"

	"github.com/defn/other/m/tenant/library/go/lib/spec/crosstenantlit"
	"github.com/rogpeppe/go-internal/testscript"
)

// TestMain wires the in-process `crosstenantlit` command for
// testscript fixtures. Each fixture's `exec crosstenantlit input.json`
// invokes runCheck against the txtar-supplied input.json.
func TestMain(m *testing.M) {
	os.Exit(testscript.RunMain(m, map[string]func() int{
		"crosstenantlit": runCheck,
	}))
}

// runCheck reads a JSON file at os.Args[1] containing
// {tenants, files, gen_writes}, runs Check, and prints "ok" when
// clean or one line per violation via Violation.Format(). Exits 0
// when clean, 1 when violations are found, 2 on usage / IO error.
func runCheck() int {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: crosstenantlit <input.json>")
		return 2
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	var input struct {
		Tenants   []crosstenantlit.Tenant     `json:"tenants"`
		Files     []crosstenantlit.SourceFile `json:"files"`
		GenWrites []string                    `json:"gen_writes"`
	}
	if err := json.Unmarshal(data, &input); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	gw := map[string]bool{}
	for _, p := range input.GenWrites {
		gw[p] = true
	}
	violations := crosstenantlit.Check(input.Tenants, input.Files, gw)
	if len(violations) == 0 {
		fmt.Println("ok")
		return 0
	}
	leafs := crosstenantlit.LeafNames(input.Tenants)
	for _, v := range violations {
		fmt.Println(v.Format(leafs))
	}
	return 1
}

func TestScripts(t *testing.T) {
	testscript.Run(t, testscript.Params{Dir: "testdata"})
}
