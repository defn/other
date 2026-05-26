// Package skill generates per-skill BUILD.bazel files from the catalog.
//
// For each skill in catalog.skills, the generator writes:
//
//	root/skills/<name>/BUILD.bazel              -- top-level brick BUILD
//	root/skills/<name>/<subdir>/BUILD.bazel     -- one per declared subdir
//
// SKILL.md is hand-edited (scaffolded by `defn stamp skill` on first
// creation). Subdir content is open-ended and convention-claimed.
package skill

import (
	"fmt"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// allowedSubdirs is the closed set of helper-content subdir names a
// skill may declare. Mirrors #SkillSubdir in kernel/schema/skill.cue
// and the four optional dirs in #RootSkillsSkill in manifest.cue.
var allowedSubdirs = map[string]bool{
	"scripts":    true,
	"references": true,
	"prompts":    true,
	"examples":   true,
}

// Run generates BUILD.bazel files for every skill in the catalog.
func Run(ctx *gen.Context) error {
	skills := ctx.CatalogQuery("skills")

	type entry struct {
		key     string
		name    string
		path    string
		subdirs []string
	}
	var entries []entry
	if err := gen.IterMap(skills, func(key string, val cue.Value) error {
		name, _ := gen.DecodeString(val, "name")
		path, _ := gen.DecodeString(val, "path")

		var subs []string
		if sd := val.LookupPath(cue.ParsePath("subdirs")); sd.Exists() {
			it, err := sd.List()
			if err == nil {
				for it.Next() {
					if s, err := it.Value().String(); err == nil {
						if !allowedSubdirs[s] {
							return fmt.Errorf("skill %q: subdir %q not in {scripts,references,prompts,examples}", key, s)
						}
						subs = append(subs, s)
					}
				}
			}
		}
		sort.Strings(subs)

		entries = append(entries, entry{
			key: gen.CueFieldKey(key), name: name, path: path, subdirs: subs,
		})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate skills: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool { return entries[i].key < entries[j].key })

	for _, e := range entries {
		// Top-level skill BUILD.bazel.
		if err := ctx.StampFromCUE(
			"kernel/interface/skill/templates.cue", e.path,
			map[string]string{"name": e.name},
			[]gen.StampFile{
				{Field: "build_bazel", Filename: "BUILD.bazel"},
			},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", e.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/", e.path))

		// One BUILD.bazel per declared subdir. Each gets the same
		// tagged_package() template; the generator never owns the
		// subdir's content.
		for _, sd := range e.subdirs {
			subPath := e.path + "/" + sd
			if err := ctx.StampFromCUE(
				"kernel/interface/skill/templates.cue", subPath,
				map[string]string{"name": e.name + "/" + sd},
				[]gen.StampFile{
					{Field: "build_bazel_subdir", Filename: "BUILD.bazel"},
				},
			); err != nil {
				return fmt.Errorf("stamp %s: %w", subPath, err)
			}
			ctx.LogOK(fmt.Sprintf("generated %s/", subPath))
		}
	}
	return nil
}
