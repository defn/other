// Package slackbot generates Slack bot instance files from the catalog.
package slackbot

import (
	"fmt"
	"sort"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// Run generates manifest.json, BUILD.bazel, mise.toml, .gitignore for each slack bot.
func Run(ctx *gen.Context) error {
	bots := ctx.CatalogQuery("slack_bots")

	type entry struct {
		key         string
		name        string
		displayName string
		fullName    string
		path        string
	}
	var entries []entry
	if err := gen.IterMap(bots, func(key string, val cue.Value) error {
		name, _ := gen.DecodeString(val, "name")
		displayName, _ := gen.DecodeString(val, "display_name")
		fullName, _ := gen.DecodeString(val, "full_name")
		path, _ := gen.DecodeString(val, "path")
		entries = append(entries, entry{
			key: gen.CueFieldKey(key), name: name,
			displayName: displayName, fullName: fullName, path: path,
		})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate slack_bots: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool { return entries[i].key < entries[j].key })

	for _, e := range entries {
		if err := ctx.StampFromCUE(
			"kernel/interface/slack-bot/templates.cue", e.path,
			map[string]string{
				"name":         e.name,
				"display_name": e.displayName,
				"full_name":    e.fullName,
			},
			[]gen.StampFile{
				{Field: "manifest_json", Filename: "manifest.json"},
				{Field: "build_bazel", Filename: "BUILD.bazel"},
				{Field: "mise_toml", Filename: "mise.toml"},
				{Field: "gitignore", Filename: ".gitignore"},
			},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", e.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/", e.path))
	}
	return nil
}
