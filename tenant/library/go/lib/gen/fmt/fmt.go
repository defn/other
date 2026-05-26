// Package fmt generates fmt BUILD.bazel files from the catalog.
package fmt

import (
	"fmt"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// Run generates fmt/<name>/BUILD.bazel for each formatter in the catalog.
func Run(ctx *gen.Context) error {
	formatters := ctx.CatalogQuery("formatters")

	var names []string
	if err := gen.IterMap(formatters, func(key string, _ cue.Value) error {
		names = append(names, gen.CueFieldKey(key))
		return nil
	}); err != nil {
		return fmt.Errorf("iterate formatters: %w", err)
	}
	sort.Strings(names)

	for _, name := range names {
		dirPath := "kernel/fmt/" + name
		if err := ctx.StampFromCUE(
			"kernel/interface/fmt/templates.cue", dirPath,
			map[string]string{"name": name},
			[]gen.StampFile{{Field: "build_bazel", Filename: "BUILD.bazel"}},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", dirPath, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel", dirPath))
	}
	return nil
}
