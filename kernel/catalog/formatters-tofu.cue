@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: tofu.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: tofu: {
	name:    "tofu"
	tool:    "opentofu"
	version: schema.versions.opentofu.version
	cmd: ["fmt"]
	extensions: [".tf", ".tfvars"]
}
