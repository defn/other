// Package gocmdcue generates Go CUE command wiring from templates.
package gocmdcue

import (
	"fmt"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/golib"
)

// Run generates BUILD.bazel + command.go for each go_cmd_cue_bricks entry.
func Run(ctx *gen.Context) error {
	bricks := ctx.CatalogQuery("go_cmd_cue_bricks")

	type entry struct {
		name string
		path string
		desc string
	}
	var entries []entry
	if err := gen.IterMap(bricks, func(_ string, v cue.Value) error {
		p, _ := gen.DecodeString(v, "path")
		desc := gen.DecodeStringOr(v, "desc", "")
		name := p[strings.LastIndex(p, "/")+1:]
		entries = append(entries, entry{name: name, path: p, desc: desc})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate go_cmd_cue_bricks: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].name < entries[j].name })

	inputs := make(map[string][]string, len(entries))
	for _, e := range entries {
		depsJSON, err := golib.ReadDepsJSON(ctx, e.path)
		if err != nil {
			return err
		}
		if err := ctx.StampFromCUE(
			"kernel/interface/go-cmd-cue/templates.cue", e.path,
			map[string]string{"name": e.name, "path": e.path, "short": e.desc, "deps": depsJSON},
			[]gen.StampFile{
				{Field: "build_bazel", Filename: "BUILD.bazel"},
				{Field: "command_go", Filename: "command.go"},
			},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", e.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel + command.go", e.path))

		files, err := golib.CollectBrickInputs(ctx.WorkDir, e.path, "command.go")
		if err != nil {
			return err
		}
		inputs[e.path] = files
	}
	if err := golib.WriteInputsBlock(ctx, "tenant/library/go/lib/gen/gocmdcue", "gocmdcue", "_gocmdcue_inputs", inputs); err != nil {
		return fmt.Errorf("write inputs block: %w", err)
	}
	return nil
}
