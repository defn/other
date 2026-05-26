// Package k8s generates k8s platform BUILD.bazel files from the catalog.
package k8s

import (
	"fmt"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// Run generates <platform.path>/BUILD.bazel for each platform; path
// is tenant-aware (tenant/<owner>/k8s/<name>) so multiple tenants
// can declare platforms without colliding.
func Run(ctx *gen.Context) error {
	// k8s uses interface/k8s package, not the catalog cache
	val, err := ctx.LoadCUEPackage("./kernel/interface/k8s", nil)
	if err != nil {
		return fmt.Errorf("load interface/k8s: %w", err)
	}
	platforms := val.LookupPath(cue.ParsePath("platforms"))

	type entry struct {
		key  string
		name string
		path string
	}
	var entries []entry
	if err := gen.IterMap(platforms, func(key string, v cue.Value) error {
		name, err := gen.DecodeString(v, "name")
		if err != nil {
			return err
		}
		path, err := gen.DecodeString(v, "path")
		if err != nil {
			return err
		}
		entries = append(entries, entry{key: key, name: name, path: path})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate platforms: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].key < entries[j].key })

	for _, e := range entries {
		if err := ctx.StampFromCUE(
			"kernel/interface/k8s/templates.cue", e.path,
			map[string]string{"name": e.name},
			[]gen.StampFile{{Field: "build_bazel", Filename: "BUILD.bazel"}},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", e.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel", e.path))
	}
	return nil
}
