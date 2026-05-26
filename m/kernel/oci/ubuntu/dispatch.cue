@experiment(aliasv2,explicitopen,shortcircuit,try)

// AIDR-00132 OQ7: per-brick worker declaration. Edit `reads`/`writes`
// when this brick reads or writes any path the generator contracts
// don't already cover. The catalog imports `worker` (AIDR-00132
// OQ7 step 3) to project brick_io.

package ubuntu

import "github.com/defn/other/kernel/spec/dispatch"

worker: dispatch.#BrickResult & {
	reads: []
	writes: []
}
