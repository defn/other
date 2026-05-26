// Package gocmdparent generates parent command wiring from the catalog.
//
// For each go-cmd-parent brick, the generator:
//  1. Finds child bricks (go-cmd with parent field set to this brick's path)
//  2. Stamps each child's command.go using the child template
//  3. Stamps the parent's command.go with child imports/wiring
package gocmdparent

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/golib"
)

type parentEntry struct {
	name string
	path string
	desc string
}

type childEntry struct {
	name       string
	path       string
	desc       string
	parentName string
	parentPath string
}

// Run generates command.go + BUILD.bazel for parent and child command bricks.
func Run(ctx *gen.Context) error {
	// Collect all parent bricks.
	parents := ctx.CatalogQuery("go_cmd_parent_bricks")
	var parentEntries []parentEntry
	if err := gen.IterMap(parents, func(_ string, v cue.Value) error {
		p, _ := gen.DecodeString(v, "path")
		desc := gen.DecodeStringOr(v, "desc", "")
		name := p[strings.LastIndex(p, "/")+1:]
		parentEntries = append(parentEntries, parentEntry{name: name, path: p, desc: desc})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate go_cmd_parent_bricks: %w", err)
	}
	sort.Slice(parentEntries, func(i, j int) bool { return parentEntries[i].name < parentEntries[j].name })

	// Collect all child bricks (go-cmd bricks with parent field set).
	allCmds := ctx.CatalogQuery("go_cmd_bricks")
	var allChildren []childEntry
	if err := gen.IterMap(allCmds, func(_ string, v cue.Value) error {
		parentPath := gen.DecodeStringOr(v, "parent", "")
		if parentPath == "" {
			return nil // not a child
		}
		p, _ := gen.DecodeString(v, "path")
		desc := gen.DecodeStringOr(v, "desc", "")
		name := p[strings.LastIndex(p, "/")+1:]
		parentName := parentPath[strings.LastIndex(parentPath, "/")+1:]
		allChildren = append(allChildren, childEntry{
			name:       name,
			path:       p,
			desc:       desc,
			parentName: parentName,
			parentPath: parentPath,
		})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate go_cmd_bricks for children: %w", err)
	}

	// Accumulate in-brick files for each processed brick (parent + each child)
	// into the gocmdparent sidecar so new hand-authored files in those
	// directories don't need spec/manual-files.cue entries.
	inputs := make(map[string][]string)

	// Process each parent.
	for _, pe := range parentEntries {
		// Find children for this parent.
		var children []childEntry
		for _, c := range allChildren {
			if c.parentPath == pe.path {
				children = append(children, c)
			}
		}
		sort.Slice(children, func(i, j int) bool { return children[i].name < children[j].name })

		// Stamp each child's command.go and BUILD.bazel.
		for _, c := range children {
			depsJSON, err := golib.ReadDepsJSON(ctx, c.path)
			if err != nil {
				return err
			}
			if err := ctx.StampFromCUE(
				"kernel/interface/go-cmd/templates.cue", c.path,
				map[string]string{
					"name":        c.name,
					"short":       c.desc,
					"deps":        depsJSON,
					"parent_name": c.parentName,
					"parent_path": c.parentPath,
				},
				[]gen.StampFile{
					{Field: "build_bazel_child", Filename: "BUILD.bazel"},
					{Field: "command_go_child", Filename: "command.go"},
				},
			); err != nil {
				return fmt.Errorf("stamp child %s: %w", c.path, err)
			}
			ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel + command.go (child of %s)", c.path, pe.name))

			files, err := golib.CollectBrickInputs(ctx.WorkDir, c.path, "command.go")
			if err != nil {
				return err
			}
			inputs[c.path] = files
		}

		// Build parent tag strings from children.
		var (
			childModules strings.Builder
			childAdds    strings.Builder
			paramParts   []string
		)
		for _, c := range children {
			fmt.Fprintf(&childModules, "\t%s.Module,\n", c.name)
			paramParts = append(paramParts, fmt.Sprintf("%sCmd *%s.SubCommand", c.name, c.name))
			fmt.Fprintf(&childAdds, "\tcmd.AddCommand(%sCmd.GetCommand())\n", c.name)
		}
		childParams := strings.Join(paramParts, ", ")

		// Read parent deps.
		depsJSON, err := golib.ReadDepsJSON(ctx, pe.path)
		if err != nil {
			return err
		}

		// Add child package deps to the parent's dep list.
		childDeps := make([]string, 0, len(children))
		for _, c := range children {
			childDeps = append(childDeps, "//"+c.path)
		}
		// Merge child deps into the extra deps JSON.
		// We prepend them so they get sorted with the rest.
		if depsJSON == "[]" {
			depsJSON = marshalStringSlice(childDeps)
		} else {
			// Parse existing, append child deps.
			depsJSON = mergeJSONArrays(depsJSON, childDeps)
		}

		// Detect if parent has a hand-written service.go.
		hasService := "false"
		if _, err := os.Stat(filepath.Join(ctx.WorkDir, pe.path, "service.go")); err == nil {
			hasService = "true"
		}

		// Build the full sorted imports block. Goal: produce a string
		// the parent template can insert as the body of its `import (...)`
		// block, already in gofmt's lexicographic order so the fmt_test
		// doesn't trip when children are tenant-pathed (sort AFTER
		// "github.com/defn/other/m/go/...") rather than the historical
		// kernel-prefixed pattern (sort BEFORE).
		thirdParty := []string{
			"github.com/defn/other/m/tenant/library/go/lib/cli",
			"github.com/spf13/cobra",
			"go.uber.org/fx",
		}
		for _, c := range children {
			thirdParty = append(thirdParty, "github.com/defn/other/m/"+c.path)
		}
		sort.Strings(thirdParty)

		var importsBlock strings.Builder
		if hasService != "true" {
			// non-service parents use fmt for the "subcommand required" error
			importsBlock.WriteString("\t\"fmt\"\n\n")
		}
		for _, p := range thirdParty {
			fmt.Fprintf(&importsBlock, "\t\"%s\"\n", p)
		}

		if err := ctx.StampFromCUE(
			"kernel/interface/go-cmd-parent/templates.cue", pe.path,
			map[string]string{
				"name":          pe.name,
				"path":          pe.path,
				"short":         pe.desc,
				"deps":          depsJSON,
				"imports_block": importsBlock.String(),
				"child_modules": childModules.String(),
				"child_params":  childParams,
				"child_adds":    childAdds.String(),
				"has_service":   hasService,
			},
			[]gen.StampFile{
				{Field: "build_bazel", Filename: "BUILD.bazel"},
				{Field: "command_go", Filename: "command.go"},
			},
		); err != nil {
			return fmt.Errorf("stamp parent %s: %w", pe.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel + command.go (parent, %d children)", pe.path, len(children)))

		parentFiles, err := golib.CollectBrickInputs(ctx.WorkDir, pe.path, "command.go")
		if err != nil {
			return err
		}
		inputs[pe.path] = parentFiles
	}

	if err := golib.WriteInputsBlock(ctx, "tenant/library/go/lib/gen/gocmdparent", "gocmdparent", "_gocmdparent_inputs", inputs); err != nil {
		return fmt.Errorf("write inputs block: %w", err)
	}

	return nil
}

func marshalStringSlice(ss []string) string {
	parts := make([]string, len(ss))
	for i, s := range ss {
		parts[i] = fmt.Sprintf("%q", s)
	}
	return "[" + strings.Join(parts, ",") + "]"
}

func mergeJSONArrays(jsonArr string, extra []string) string {
	// Simple: strip brackets, combine.
	inner := strings.TrimSpace(jsonArr)
	inner = strings.TrimPrefix(inner, "[")
	inner = strings.TrimSuffix(inner, "]")
	extraParts := make([]string, len(extra))
	for i, s := range extra {
		extraParts[i] = fmt.Sprintf("%q", s)
	}
	combined := inner
	if combined != "" {
		combined += ","
	}
	combined += strings.Join(extraParts, ",")
	return "[" + combined + "]"
}
