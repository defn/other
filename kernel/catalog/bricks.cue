@experiment(aliasv2,explicitopen,shortcircuit,try)

// bricks.cue -- BRICK directory classification inventory.
//
// Brick entries are split into individual files: brick-<path>.cue
// Each file defines one brick. This file provides the schema
// constraint that all brick values must satisfy.
package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick
