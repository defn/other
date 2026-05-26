@experiment(aliasv2,explicitopen,shortcircuit,try)

// Library app catalog. Per-app instance data lives in
// tenant/library/catalog/apps-<name>.cue (sharded per AIDR-00083
// leaves-into-branches). This file holds the package declaration
// + schema constraint only.
package catalog

import "github.com/defn/other/kernel/schema"

apps: [string]: schema.#App
