@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: markdown.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: markdown: {
	name:    "markdown"
	tool:    "prettier"
	version: schema.versions.prettier.version
	cmd: ["--write", "--prose-wrap", "preserve"]
	extensions: [".md"]
}
