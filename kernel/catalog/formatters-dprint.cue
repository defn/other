@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: dprint.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: dprint: {
	name:    "dprint"
	tool:    "dprint"
	version: schema.versions.dprint.version
	cmd: ["fmt"]
	extensions: ["Dockerfile"]
}
