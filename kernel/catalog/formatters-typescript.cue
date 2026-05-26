@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: typescript.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: typescript: {
	name:    "typescript"
	tool:    "biome"
	version: schema.versions.biome.version
	cmd: ["format", "--write"]
	extensions: [".ts"]
}
