@experiment(aliasv2,explicitopen,shortcircuit,try)

// Hand-edited overlay marking bricks as `shared` for the AIDR-00132
// dispatch partitioner. The catalog's per-brick `brick-<slug>.cue`
// files are generator-owned (the `restamp` phase re-emits them from
// the StampBrick template, dropping hand-added fields). This sidecar
// file is NOT generator-owned -- restamp leaves it alone -- so
// shared markers survive `mise run hatch`.
//
// `shared: true` means the coordinator merges this brick itself
// rather than dispatching it to a parallel sub-agent. Mark a brick
// when:
//
//   - It aggregates many descendants and the partitioner clusters
//     them all into one big group (use `defn dispatch --all
//     --plan-only` and look at the largest groups).
//   - Or its content is read by many other bricks (catalog dirs,
//     interface dirs).
//
// CUE unifies this map with the per-brick brick-<slug>.cue files;
// the schema's `shared?: bool` field accepts both the inline form
// and this sidecar overlay. Branch / relationship / interface
// kinds default to shared by inference and don't need an entry.

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/go/lib/gen": shared: true // Aggregates 26 generators; coordinator merges gen-level state.
}
