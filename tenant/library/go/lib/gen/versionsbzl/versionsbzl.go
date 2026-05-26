// Package versionsbzl generates per-tool Starlark version files from schema.
package versionsbzl

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// Run generates kernel/gen-versions/<tool>.bzl for each version entry.
func Run(ctx *gen.Context) error {
	versions := ctx.SchemaQuery("versions")
	dir := "kernel/gen-versions"
	os.MkdirAll(filepath.Join(ctx.WorkDir, dir), 0o755)

	type entry struct {
		name string
		val  cue.Value
	}
	var entries []entry
	if err := gen.IterMap(versions, func(key string, v cue.Value) error {
		entries = append(entries, entry{name: gen.CueFieldKey(key), val: v})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate versions: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].name < entries[j].name })

	for _, e := range entries {
		base := strings.ToUpper(strings.ReplaceAll(e.name, "-", "_"))
		version, _ := gen.DecodeString(e.val, "version")
		chartVer := gen.DecodeStringOr(e.val, "chart_version", "")
		chartSHA := gen.DecodeStringOr(e.val, "chart_sha256", "")

		var sb strings.Builder
		sb.WriteString("# Generated from schema/versions.cue -- DO NOT EDIT.\n")
		fmt.Fprintf(&sb, "%s_VERSION = \"%s\"\n", base, version)
		if chartVer != "" {
			fmt.Fprintf(&sb, "%s_CHART_VERSION = \"%s\"\n", base, chartVer)
		}
		if chartSHA != "" {
			fmt.Fprintf(&sb, "%s_CHART_SHA256 = \"%s\"\n", base, chartSHA)
		}

		filename := filepath.Join(ctx.WorkDir, dir, e.name+".bzl")
		content := sb.String()

		// Only write if content changed
		existing, _ := os.ReadFile(filename)
		if string(existing) != content {
			if _, err := gen.WriteIfChanged(filename, []byte(content), 0o644); err != nil {
				return fmt.Errorf("write %s: %w", filename, err)
			}
		}
		ctx.LogOK(fmt.Sprintf("generated %s/%s.bzl", dir, e.name))
	}
	return nil
}
