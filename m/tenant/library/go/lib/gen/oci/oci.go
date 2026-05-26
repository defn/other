// Package oci generates OCI image BUILD.bazel files from the catalog.
package oci

import (
	"fmt"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// Run generates oci/<name>/BUILD.bazel for each oci_images entry.
func Run(ctx *gen.Context) error {
	images := ctx.CatalogQuery("oci_images")

	type entry struct {
		key  string
		name string
	}
	var entries []entry
	if err := gen.IterMap(images, func(key string, val cue.Value) error {
		name, err := gen.DecodeString(val, "name")
		if err != nil {
			return fmt.Errorf("oci %s: %w", key, err)
		}
		entries = append(entries, entry{key: key, name: name})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate oci_images: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool { return entries[i].key < entries[j].key })

	for _, e := range entries {
		dirPath := "kernel/oci/" + e.name
		if err := ctx.StampFromCUE(
			"kernel/interface/oci/templates.cue", dirPath,
			map[string]string{"name": e.name},
			[]gen.StampFile{{Field: "build_bazel", Filename: "BUILD.bazel"}},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", dirPath, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/", dirPath))
	}
	return nil
}
