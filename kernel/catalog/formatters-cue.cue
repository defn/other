@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: cue.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: cue: {
	name:    "cue"
	tool:    "cue"
	version: schema.versions.cue.version
	cmd: ["fmt"]
	extensions: [".cue"]
}
