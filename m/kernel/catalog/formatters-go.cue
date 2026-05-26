@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: go.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: go: {
	name:    "go"
	tool:    "gofmt"
	version: schema.versions.go.version
	cmd: ["-w"]
	extensions: [".go"]
}
