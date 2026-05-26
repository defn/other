@experiment(aliasv2,explicitopen,shortcircuit,try)

// Formatter instance: clojure.
//
// Per-formatter catalog shard per AIDR-00083 (leaves-into-branches).
// Each formatter is a leaf; formatters map is the branch computed
// from leaves.

package catalog

import "github.com/defn/other/kernel/schema"

formatters: clojure: {
	name:    "clojure"
	tool:    "cljstyle"
	version: schema.versions.cljstyle.version
	cmd: ["fix"]
	extensions: [".clj"]
	runtime: "jar"
}
