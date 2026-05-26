@experiment(aliasv2,explicitopen,shortcircuit,try)

// Coordinator dispatch protocol schema (AIDR-00132).
//
// `defn hatch --brick=<path>` and `defn dispatch` exchange CUE values
// shaped by these definitions. The same #DispatchPlan is both the
// coordinator's running plan AND the snapshot fed into each
// per-brick hatch via --since-snapshot. Per-brick hatch writes a
// #BrickResult to --result-out; the coordinator unifies the result
// into its plan, then re-emits the plan as the snapshot for the
// next dispatch wave.
//
// Schema locality: this file is the canonical type. Multiple
// coordinators share the namespace -- they are plan instances, not
// schema variants. Each brick that opts into per-brick declaration
// imports this package and unifies its own `worker:
// dispatch.#BrickResult & {...}` against #BrickResult in a
// `dispatch.cue` co-located with the brick's source dir
// (AIDR-00132 open question 7's three-step migration).
//
// References:
//   - AIDR-00132 -- the F1 spec; this schema is the wire format.
//   - AIDR-00131 -- brickreads.Diff is the staleness self-check
//     `blockedOn` mirrors.
//   - AIDR-00089 -- `blocked` brick status (log and abandon).

package dispatch

// #DispatchPlan is the running record of a coordinator dispatch
// round. The empty plan (no brick keys) is a valid #DispatchPlan
// and represents "first dispatch wave, nothing yet completed".
//
// As agents complete, the coordinator unifies their #BrickResult
// values into `bricks[<slug>]`. The resulting plan is monotonic:
// once a brick lands a result, the coordinator never reverses it
// in this run -- the next wave's snapshot includes every prior
// wave's writes.
#DispatchPlan: {
	// Slug-keyed map of completed brick results. Keys are catalog
	// slugs (e.g. "go--cmd--hello").
	bricks: [string]: #BrickResult
}

// #BrickResult is the per-brick dispatch outcome. Echoed back by
// `defn hatch --brick=<path>` as result CUE; consumed by the
// coordinator to update the running plan and to feed the next
// wave's snapshot.
#BrickResult: {
	// The brick's declared reads/writes. Echoed in the result so
	// the coordinator does not re-load the brick's source-dir
	// dispatch.cue at merge time.
	reads: [...string]
	writes: [...string]

	// Outcome of the per-brick hatch run. Canonical status; the
	// process exit code is just a coarse health signal.
	//
	//   - idempotent:    gen + buildsync subset reached equilibrium.
	//                    Coordinator accepts the result.
	//   - blocked:       F1 self-check found this brick's reads
	//                    intersect a sibling's writes-since-dispatch.
	//                    Coordinator re-plans (AIDR-00089).
	//   - dirty:         a generator wrote outside the brick's path
	//                    -- contract violation. Coordinator treats as
	//                    blocked and re-plans.
	//   - not-converged: cycle iteration cap was hit.
	//   - error:         residual catch-all. Process usually exits
	//                    non-zero before reaching this.
	status: "idempotent" | "blocked" | "dirty" | "not-converged" | "error"

	// Populated when status == "blocked". Mirrors the brickreads.Stale
	// shape so the coordinator can pretty-print the staleness path.
	blockedOn?: [...{
		sibling: string
		paths: [...string]
	}]

	// sha256 over the brick's tracked content post-equilibrium.
	// The coordinator's lattice-merge step at the dispatch boundary
	// consumes this without re-fingerprinting from disk.
	fingerprint?: string

	// session_id is the resumable Claude Code (Agent Client
	// Protocol) session identifier for this brick's agent run.
	// Populated when the agent ran via --acp-prompt; empty for
	// shell-out (--agent-cmd) and for read-only F1 fingerprint
	// runs. Resume with `claude --resume <session_id>` to debug
	// or continue.
	session_id?: string

	// log_path is the workspace-relative path to the per-agent
	// stdout/stderr log file (.defn/dispatch/<run>/logs/<slug>.log).
	// Populated when the agent ran via --acp-prompt or
	// --agent-cmd; empty for in-process CycleBrick runs.
	log_path?: string

	// out_of_lane_patch is the workspace-relative path to the
	// sidecar diff containing edits the agent made outside its
	// brick's lane. Present only when the agent committed paths
	// that did not prefix-match brickPath. The patch is anchored
	// at the agent's fork-point commit; apply via `git apply
	// --3way` against any later coord state. AIDR-00135.
	out_of_lane_patch?: string

	// Per-agent token usage and cost reported by the ACP bridge.
	// Counts come from the bridge's UsageUpdate stream and the
	// final PromptResponse.Usage; cost comes from
	// SessionUsageUpdate.cost. All fields are optional because
	// non-ACP dispatch paths (--agent-cmd, in-process CycleBrick)
	// don't emit them. UNSTABLE in the ACP spec; absence here is
	// also expected when the bridge version doesn't surface them.
	tokens_input?:       int
	tokens_output?:      int
	tokens_cache_read?:  int
	tokens_cache_write?: int
	tokens_thought?:     int
	tokens_total?:       int

	// Cumulative session cost. Amount is float; currency is
	// ISO 4217 (typically "USD"). Emitted only when the bridge
	// supplies it via SessionUsageUpdate.cost.
	cost_amount?:   float64
	cost_currency?: string
}
