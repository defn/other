@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: yaml.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: yaml: {
	name:    "yaml"
	tool:    "yq"
	version: schema.versions.yq.version
	cmd: ["-i", "."]
	extensions: [".yaml", ".yml"]
}
