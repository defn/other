// Package gocmd generates Go command wiring and modules.go from templates.
package gocmd

import (
	"fmt"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/golib"
)

// Run generates BUILD.bazel + command.go for each go_cmd_bricks entry,
// and modules.go aggregating all command types.
func Run(ctx *gen.Context) error {
	// go-cmd bricks (plain cobra commands)
	cmdBricks := ctx.CatalogQuery("go_cmd_bricks")
	type entry struct {
		name string
		path string
		desc string
	}
	var commands []entry
	if err := gen.IterMap(cmdBricks, func(_ string, v cue.Value) error {
		// Skip children -- handled by gocmdparent generator.
		if gen.DecodeStringOr(v, "parent", "") != "" {
			return nil
		}
		p, _ := gen.DecodeString(v, "path")
		desc := gen.DecodeStringOr(v, "desc", "")
		name := p[strings.LastIndex(p, "/")+1:]
		commands = append(commands, entry{name: name, path: p, desc: desc})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate go_cmd_bricks: %w", err)
	}
	sort.Slice(commands, func(i, j int) bool { return commands[i].name < commands[j].name })

	// Stamp each go-cmd brick
	inputs := make(map[string][]string, len(commands))
	for _, e := range commands {
		depsJSON, err := golib.ReadDepsJSON(ctx, e.path)
		if err != nil {
			return err
		}
		if err := ctx.StampFromCUE(
			"kernel/interface/go-cmd/templates.cue", e.path,
			map[string]string{"name": e.name, "path": e.path, "short": e.desc, "deps": depsJSON},
			[]gen.StampFile{
				{Field: "build_bazel", Filename: "BUILD.bazel"},
				{Field: "command_go", Filename: "command.go"},
			},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", e.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel + command.go", e.path))

		// Sidecar: auto-claim in-brick hand-authored files (service.go,
		// deps.cue, schema.cue, ...) so they don't need spec/manual-files.cue
		// entries. BUILD.bazel + command.go are generator outputs claimed
		// via the static paths list in gocmd/contract.cue.
		files, err := golib.CollectBrickInputs(ctx.WorkDir, e.path, "command.go")
		if err != nil {
			return err
		}
		inputs[e.path] = files
	}
	if err := golib.WriteInputsBlock(ctx, "tenant/library/go/lib/gen/gocmd", "gocmd", "_gocmd_inputs", inputs); err != nil {
		return fmt.Errorf("write inputs block: %w", err)
	}

	// All commands (go-cmd + go-cmd-cue) for modules.go
	allCmds := ctx.CatalogQuery("go_commands")
	var allEntries []entry
	if err := gen.IterMap(allCmds, func(_ string, v cue.Value) error {
		// Skip children -- included via parent's Module.
		if gen.DecodeStringOr(v, "parent", "") != "" {
			return nil
		}
		p, _ := gen.DecodeString(v, "path")
		name := p[strings.LastIndex(p, "/")+1:]
		allEntries = append(allEntries, entry{name: name, path: p})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate go_commands: %w", err)
	}

	// Add root to the list. `root` has no catalog entry (it's the cobra
	// root wrapper), so it still resolves via go/cmd/root until
	// AIDR-00141 Stage 1 moves it.
	allWithRoot := append([]entry{{name: "root"}}, allEntries...)

	// Sort by full import path so the rendered import block matches
	// gofmt's lexicographic import-sort order. Sorting by `name` was
	// fine when every cmd lived at github.com/defn/other/m/go/cmd/<name>
	// (path order == name order), but AIDR-00141 moves bricks to
	// github.com/defn/other/m/tenant/library/go/cmd/<name>, breaking
	// that invariant -- "dispatch" sorts before "gen" by name but
	// "tenant/.../dispatch" sorts AFTER "go/.../gen" by path.
	pathFor := func(e entry) string {
		if e.path == "" {
			// root is the only cmd without a catalog entry. AIDR-00141
			// Stage 1 moves it to tenant/library/go/cmd/root alongside
			// the other Tier 1 cmds. Hardcoded here because root has
			// no `implements` field; go_commands query doesn't see it.
			if e.name == "root" {
				return "tenant/library/go/cmd/root"
			}
			return "go/cmd/" + e.name
		}
		return e.path
	}
	sort.Slice(allWithRoot, func(i, j int) bool {
		return pathFor(allWithRoot[i]) < pathFor(allWithRoot[j])
	})

	// Build imports and refs strings. Use the brick's path (catalog
	// authoritative) so post-AIDR-00141 moves produce correct imports.
	var imports, refs strings.Builder
	for _, e := range allWithRoot {
		fmt.Fprintf(&imports, "\t\"github.com/defn/other/m/%s\"\n", pathFor(e))
		fmt.Fprintf(&refs, "\t%s.Module,\n", e.name)
	}

	// Stamp at the active tenant's namesake CLI app dir
	// (tenant/<default_tenant>/go/cmd/<default_tenant>/app/modules.go).
	// AIDR-00141 Stage 3.5d: per-tenant namesake CLIs are stamped by the
	// tenant-cli flow at bootstrap; modules.go is then refreshed here on
	// every hatch from the catalog.
	tenant := ctx.DefaultTenant()
	appDir := "tenant/" + tenant + "/go/cmd/" + tenant + "/app"
	if err := ctx.StampFromCUE(
		"kernel/interface/go-cmd/templates.cue", appDir,
		map[string]string{
			"name":            "modules",
			"short":           "",
			"deps":            "[]",
			"modules_imports": imports.String(),
			"modules_refs":    refs.String(),
		},
		[]gen.StampFile{{Field: "modules_go", Filename: "modules.go"}},
	); err != nil {
		return fmt.Errorf("stamp modules.go: %w", err)
	}
	ctx.LogOK("generated " + appDir + "/modules.go")
	return nil
}
