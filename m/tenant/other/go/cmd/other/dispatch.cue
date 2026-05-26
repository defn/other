@experiment(aliasv2,explicitopen,shortcircuit,try)

// Per-brick worker declaration (AIDR-00132 OQ7). Fork stamps this as
// part of the namesake-CLI seed; edit reads/writes when the brick
// reads or writes any path not already covered by generator contracts.

package deps

import "github.com/defn/other/kernel/spec/dispatch"

worker: dispatch.#BrickResult & {
	reads: []
	writes: []
}
