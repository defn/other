@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: toml.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: toml: {
	name:    "toml"
	tool:    "taplo"
	version: schema.versions.taplo.version
	cmd: ["format"]
	extensions: [".toml"]
}
