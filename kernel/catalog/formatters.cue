@experiment(aliasv2,explicitopen,shortcircuit,try)

// formatters.cue -- formatter inventory aggregated from fmt/ components.
//
// Each formatter maps a file type to its tool, command, and extensions.
// Versions are resolved from schema.versions (single source of truth).
//
// Per-formatter instance data lives in formatters-<name>.cue (sharded
// per AIDR-00083 leaves-into-branches). This file holds only the
// schema constraint binding.
package catalog

import "github.com/defn/other/kernel/schema"

formatters: [string]: schema.#Formatter
