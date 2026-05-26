@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: python.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: python: {
	name:    "python"
	tool:    "ruff"
	version: schema.versions.ruff.version
	cmd: ["format"]
	extensions: [".py"]
}
