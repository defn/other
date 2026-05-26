@experiment(aliasv2,explicitopen,shortcircuit,try)

// Schema constraint only. App instances live in
// tenant/library/catalog/apps.cue (shared) and
// tenant/defn/catalog/apps.cue (defn-specific).
package catalog

import "github.com/defn/other/kernel/schema"

apps: [string]: schema.#App
