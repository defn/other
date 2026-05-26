@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

// Minimal leaf-tenant stub created by `defn bootstrap init`
// (AIDR-00138 stand-in). Replace with real tenant config when the
// fork builds out its own tenancy.
auth: schema.#Auth & {tofu: "other-org"}
