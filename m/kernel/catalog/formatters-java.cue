@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: java.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: java: {
	name:    "java"
	tool:    "google-java-format"
	version: schema.versions."google-java-format".version
	cmd: ["--replace"]
	extensions: [".java"]
	runtime: "jar"
}
