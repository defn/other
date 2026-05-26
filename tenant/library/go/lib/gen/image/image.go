// Package image generates container image BUILD.bazel and mise.toml from the catalog.
package image

import (
	"fmt"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// Run generates image/docker/<name>/BUILD.bazel and mise.toml.
func Run(ctx *gen.Context) error {
	images := ctx.CatalogQuery("container_images")

	type entry struct {
		key      string
		name     string
		imageTag string
		base     string
	}
	var entries []entry
	if err := gen.IterMap(images, func(key string, v cue.Value) error {
		name, _ := gen.DecodeString(v, "name")
		imageTag, _ := gen.DecodeString(v, "image_tag")
		base, _ := gen.DecodeString(v, "base")
		entries = append(entries, entry{key: key, name: name, imageTag: imageTag, base: base})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate container_images: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].key < entries[j].key })

	for _, e := range entries {
		dirPath := "kernel/image/docker/" + e.name
		if err := ctx.StampFromCUE(
			"kernel/interface/image/templates.cue", dirPath,
			map[string]string{"name": e.name, "image_tag": e.imageTag, "base": e.base},
			[]gen.StampFile{
				{Field: "build_bazel", Filename: "BUILD.bazel"},
				{Field: "mise_toml", Filename: "mise.toml"},
			},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", dirPath, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/", dirPath))
	}
	return nil
}
