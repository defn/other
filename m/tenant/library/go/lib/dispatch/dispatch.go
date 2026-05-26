// Package dispatch is the coordinator for parallel per-brick hatch
// dispatch (AIDR-00132 / AIDR-00133).
//
// Walks a brick set and invokes the AIDR-00132 F1 primitive (per-
// brick equilibrium) for each, accumulating per-brick #BrickResult
// values into a running #DispatchPlan. The coordinator is the
// canonical caller of the F1 protocol -- standalone `defn hatch
// --brick=<path>` exists primarily for tests and dev iteration.
//
// AIDR-00133 specifies a sequential stub. This implementation also
// supports parallel fan-out via --parallel=K to make the demo
// concrete: agent coordinators plan a lot of work and dispatch it to
// K parallel sub-agents to amplify a small set of humans (the
// AIDR-00132 motivation). Sequential remains the default until
// per-brick isolation guarantees stabilize.
//
// What this package is NOT: a worktree manager (AIDR-00076 items 4
// + 5), a planner (AIDR-00084), or a replan loop (AIDR-00086). The
// stub is deliberately dumb -- catalog-order dispatch, no retry, no
// replan -- so we can prove the F1 protocol round-trip without
// blocking on F2's full design.
package dispatch

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"sync"
	"time"

	"github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// gitRevParse resolves a revision (e.g. "HEAD") to a commit SHA in
// workDir.
func gitRevParse(ctx context.Context, workDir, rev string) (string, error) {
	out, err := runner.Output(ctx, runner.Opts{
		Args: []string{"git", "rev-parse", rev},
		Dir:  workDir,
	})
	if err != nil {
		return "", fmt.Errorf("rev-parse %s: %w", rev, err)
	}
	return out, nil
}

// fileExists is true iff stat succeeds. Used to gate the per-slug
// plan-file mirror under --acp-prompt: if the operator didn't
// pre-author a plan for this slug, we just don't copy anything
// and the agent gets {{plans_dir}} pointing at an empty dir.
func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// writePartitionCUE writes the dispatch partition to disk as JSON
// (a CUE subset). Schema-side, it conforms to a future
// `dispatch.#Partition` definition; for now the shape is the
// Partition struct's JSON tags.
func writePartitionCUE(path string, p Partition) error {
	if dir := filepath.Dir(path); dir != "." && dir != "" {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	data, err := json.MarshalIndent(p, "", "\t")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0o644)
}

// Config captures one dispatch run's inputs.
type Config struct {
	// Target is one brick slug-or-path. The coordinator runs Plan
	// to compute the involved set (target + path-overlapping
	// siblings) and dispatches them. This is the coordinator-first
	// shape: the user picks ONE brick to work on; the planner
	// figures out what else to include. Mutually exclusive with
	// Bricks and All.
	Target string

	// Bricks is the explicit slug list (escape hatch for tests and
	// dev iteration). Mutually exclusive with Target and All.
	Bricks []string

	// All requests dispatching every component brick from the
	// lattice (slug-sorted). Mutually exclusive with the others.
	All bool

	// Parallel is the maximum number of in-flight dispatches.
	// 1 = sequential (AIDR-00133 stub). >1 = fan-out (the F2
	// motivation, demonstrated here at small K). Defaults to 1.
	Parallel int

	// PlanOut is the path for the final running plan CUE. Empty =
	// .defn/dispatch/<run-id>/plan.cue.
	PlanOut string

	// PlanOnly skips actual dispatch. The coordinator computes the
	// partition (shared bricks + disjoint sub-agent groups) and
	// writes the plan CUE; the operator inspects it before running
	// any agents. Pairs naturally with --target / --all to scope
	// the input set.
	PlanOnly bool

	// Worktree spawns one git worktree per dispatched brick,
	// branched from the coordinator's HEAD. Each agent runs inside
	// its worktree; the coordinator merges agent branches back at
	// the end. This is the F2 isolation contract (AIDR-00076 items
	// 4 + 5).
	Worktree bool

	// ACPPrompt drives Claude Code via the Agent Client Protocol
	// (github.com/coder/acp-go-sdk). Four placeholders ({{slug}},
	// {{worktree}}, {{run}}, {{plans_dir}}) are templated into the
	// prompt. Empty = no agent (read-only F1 fingerprint via
	// CycleBrick).
	//
	// Recommended shape: pass a PATH to a plan file rather than
	// embedding plan content. The plan stays in the coordinator's
	// filesystem; the agent reads it via the path. Short prompt,
	// cache-friendly, no escaping:
	//
	//   use the sp-bricks skill on {{plans_dir}}/{{slug}}.md
	//
	// The coordinator (= user's interactive Claude Code) writes the
	// plan files BEFORE running dispatch. PlansDir is the stable
	// directory those files live in -- decoupled from the dispatcher's
	// run-id so plans can be authored once and reused.
	ACPPrompt string

	// PlansDir is the directory the coordinator pre-authors per-
	// brick plan files in. Default: <workDir>/.defn/dispatch/plans.
	// Substituted into ACPPrompt as {{plans_dir}}. Stable across
	// runs by design: the operator authors plans once, dispatches
	// repeatedly. Resolves to an absolute path before substitution.
	PlansDir string

	// ACPBridge is the command that adapts ACP to Claude Code.
	// Default: ["claude-agent-acp"], the mise-pinned binary
	// (kernel/schema/versions.cue: claude-agent-acp). Override via
	// --acp-bridge if you need a different bridge or version.
	ACPBridge []string
}

// Run executes one coordinator dispatch round and returns the
// process exit code:
//   - 0: every brick reached `idempotent`.
//   - 1: at least one brick came back blocked / dirty / not-converged.
//   - 2: process error (catalog load, bad flags).
func Run(cfg Config) (int, error) {
	modes := 0
	if cfg.Target != "" {
		modes++
	}
	if len(cfg.Bricks) > 0 {
		modes++
	}
	if cfg.All {
		modes++
	}
	if modes == 0 {
		return 2, fmt.Errorf("dispatch: must specify --target=<slug>, --bricks=..., or --all")
	}
	if modes > 1 {
		return 2, fmt.Errorf("dispatch: --target / --bricks / --all are mutually exclusive")
	}
	if cfg.Parallel < 1 {
		cfg.Parallel = 1
	}
	if cfg.Parallel > runtime.NumCPU()*4 {
		cfg.Parallel = runtime.NumCPU() * 4
	}

	runID := time.Now().UTC().Format("20060102T150405Z")
	runDir := filepath.Join(".defn", "dispatch", runID)
	snapshotDir := filepath.Join(runDir, "snapshots")
	resultDir := filepath.Join(runDir, "results")
	for _, d := range []string{snapshotDir, resultDir} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return 2, fmt.Errorf("mkdir %s: %w", d, err)
		}
	}

	workDir, err := hatch.FindWorkspaceRoot()
	if err != nil {
		return 2, fmt.Errorf("dispatch: %w", err)
	}
	allBricks, err := hatch.LoadBricks(workDir)
	if err != nil {
		return 2, fmt.Errorf("dispatch: %w", err)
	}

	bricks := cfg.Bricks
	switch {
	case cfg.All:
		if cfg.PlanOnly {
			// In plan-only mode, partition over EVERY brick so branches
			// and relationships get classified as shared instead of
			// silently skipped. Dispatch-mode --all keeps the
			// component-only filter because branches aren't valid
			// CycleBrick targets.
			for slug := range allBricks {
				if slug == "" {
					continue
				}
				bricks = append(bricks, slug)
			}
			sort.Strings(bricks)
		} else {
			slugs, err := hatch.AllComponentSlugs(workDir)
			if err != nil {
				return 2, fmt.Errorf("dispatch --all: %w", err)
			}
			bricks = slugs
		}
	case cfg.Target != "":
		involved, err := Plan(cfg.Target, allBricks)
		if err != nil {
			return 2, err
		}
		fmt.Printf("✓ dispatch: target=%s -> %d involved bricks (path-overlap rule)\n", cfg.Target, len(involved))
		bricks = involved
	}

	if cfg.PlanOnly {
		// Restrict the partition's universe to the selected bricks.
		subset := make(map[string]hatch.BrickInfo, len(bricks))
		for _, slug := range bricks {
			if b, ok := allBricks[slug]; ok {
				subset[slug] = b
			}
		}
		partition := PartitionBricks(subset)
		planOut := cfg.PlanOut
		if planOut == "" {
			planOut = filepath.Join(runDir, "partition.cue")
		}
		if err := writePartitionCUE(planOut, partition); err != nil {
			return 2, fmt.Errorf("write partition: %w", err)
		}
		fmt.Println()
		fmt.Printf("dispatch plan (run %s):\n", runID)
		fmt.Printf("  %d bricks in scope\n", len(subset))
		fmt.Printf("  %d shared (coordinator's queue)\n", len(partition.Shared))
		fmt.Printf("  %d sub-agents can dispatch in parallel\n", partition.AgentCount())
		groupKeys := make([]string, 0, len(partition.Groups))
		for k := range partition.Groups {
			groupKeys = append(groupKeys, k)
		}
		sort.Strings(groupKeys)
		for _, k := range groupKeys {
			fmt.Printf("    agent %s -> %d bricks\n", k, len(partition.Groups[k]))
		}
		// Suggest sharing candidates: any non-shared group root whose
		// descendant count exceeds the threshold is a likely
		// `shared: true` mark. Marking a group root shared splits its
		// subtree into separate sub-agent groups, increasing parallelism.
		// Threshold default is 8 -- groups smaller than that don't move
		// the parallelism needle enough to be worth the metadata churn.
		if cands := suggestSharedCandidates(partition, 8); len(cands) > 0 {
			fmt.Println()
			fmt.Println("candidates to mark shared (largest non-shared aggregators):")
			for _, c := range cands {
				fmt.Printf("    %s -> %d descendants  (mark shared: true to split into %d agents)\n", c.slug, c.size, c.size-1)
			}
			fmt.Println("  add to kernel/catalog/shared-bricks.cue:")
			fmt.Println("    \"<slug>\": shared: true")
		}
		fmt.Printf("plan written to %s\n", planOut)
		return 0, nil
	}

	// Worktree-per-agent (cfg.Worktree). Each agent gets its own
	// `git worktree add .defn/dispatch/<run>/wt/<slug>` branched from
	// HEAD; the agent runs entirely inside that worktree; the
	// coordinator merges the agent's branch back at the end. This is
	// the F2 isolation contract (AIDR-00076 items 4 + 5) -- proves
	// that concurrent agents can't collide on shared writes because
	// each touches a different working directory.
	//
	// Worktree creation is sequential here (cheap; ~50ms each) so we
	// can detect any git-state issue before fanning out. Agents
	// themselves run in parallel under the existing semaphore.

	worktrees := map[string]*Worktree{}
	if cfg.Worktree {
		for _, slug := range bricks {
			wt, err := CreateWorktree(context.Background(), workDir, runID, slug)
			if err != nil {
				// Cleanup any we created before bailing.
				for _, w := range worktrees {
					_ = RemoveWorktree(context.Background(), workDir, w)
				}
				return 2, fmt.Errorf("dispatch: create worktree for %s: %w", slug, err)
			}
			worktrees[slug] = wt
			fmt.Printf("✓ dispatch: worktree %s -> %s\n", slug, wt.Path)
		}
		// Always tear worktrees down at the end of the run, even on
		// error. The defer protects against panics or partial fan-out.
		defer func() {
			for _, w := range worktrees {
				_ = RemoveWorktree(context.Background(), workDir, w)
			}
		}()
	}

	plan := &hatch.DispatchPlan{Bricks: map[string]hatch.BrickResult{}}
	var planMu sync.Mutex
	results := make(chan brickOutcome, len(bricks))

	fmt.Printf("✓ dispatch: run %s, %d bricks, parallel=%d", runID, len(bricks), cfg.Parallel)
	if cfg.Worktree {
		fmt.Printf(", worktree=true")
	}
	fmt.Println()

	sem := make(chan struct{}, cfg.Parallel)
	var wg sync.WaitGroup
	start := time.Now()

	for _, slug := range bricks {
		slug := slug
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			snap := filepath.Join(snapshotDir, slug+".cue")
			out := filepath.Join(resultDir, slug+".cue")

			// Snapshot is captured BEFORE the agent starts. Each
			// dispatched brick sees the plan as-of-now -- subsequent
			// completions don't retroactively appear in this brick's
			// snapshot. Mirrors AIDR-00132's coordinator semantics.
			planMu.Lock()
			snapshot := clonePlan(plan)
			planMu.Unlock()

			if err := hatch.WritePlanCUE(snap, snapshot); err != nil {
				results <- brickOutcome{slug: slug, err: err}
				return
			}

			agentWorkDir := ""
			if wt, ok := worktrees[slug]; ok {
				agentWorkDir = wt.AgentWorkDir
			}
			t0 := time.Now()
			var err error
			if cfg.ACPPrompt != "" {
				if agentWorkDir == "" {
					err = fmt.Errorf("--acp-prompt requires --worktree")
				} else {
					logPath := filepath.Join(runDir, "logs", slug+".log")
					bridge := cfg.ACPBridge
					if len(bridge) == 0 {
						// Mise-pinned shim resolves to the version
						// declared in kernel/schema/versions.cue
						// (claude-agent-acp). Avoids `npx -y ...@latest`
						// network round trips on every dispatch.
						bridge = []string{"claude-agent-acp"}
					}
					plansDir := cfg.PlansDir
					if plansDir == "" {
						plansDir = filepath.Join(workDir, ".defn", "dispatch", "plans")
					}
					if !filepath.IsAbs(plansDir) {
						plansDir = filepath.Join(workDir, plansDir)
					}
					// Mirror the per-slug plan file into the agent's
					// worktree so the prompt's plans-dir path lives
					// inside the worktree. Reading the plan from
					// outside the worktree primes some agents to
					// resolve subsequent relative paths against the
					// coordinator's main checkout instead of their
					// session cwd, which leaks edits there (TODO 1b,
					// observed 2026-05-09 on runs 20260510T062330Z /
					// 20260510T064657Z / 20260510T065149Z; env scrub
					// alone reduced 3-of-4 leaks to 1-of-4).
					agentPlansDir := filepath.Join(agentWorkDir, ".defn", "dispatch", "plans")
					if src := filepath.Join(plansDir, slug+".md"); fileExists(src) {
						_ = os.MkdirAll(agentPlansDir, 0o755)
						dst := filepath.Join(agentPlansDir, slug+".md")
						if data, rerr := os.ReadFile(src); rerr == nil {
							_ = os.WriteFile(dst, data, 0o644)
						}
					}
					var runInfo agentRunInfo
					runInfo, err = runAgentACP(context.Background(), bridge, cfg.ACPPrompt, slug, runID, agentWorkDir, logPath, agentPlansDir)
					if err == nil {
						err = autoCommitWorktree(context.Background(), agentWorkDir, slug)
					}
					if err == nil {
						_ = hatch.WriteResultCUE(out, hatch.BrickResult{
							Reads:            []string{},
							Writes:           []string{},
							Status:           "idempotent",
							SessionID:        runInfo.SessionID,
							LogPath:          logPath,
							TokensInput:      runInfo.InputTokens,
							TokensOutput:     runInfo.OutputTokens,
							TokensCacheRead:  runInfo.CacheReadTokens,
							TokensCacheWrite: runInfo.CacheWriteTokens,
							TokensThought:    runInfo.ThoughtTokens,
							TokensTotal:      runInfo.TotalTokens,
							CostAmount:       runInfo.CostAmount,
							CostCurrency:     runInfo.CostCurrency,
						})
					}
				}
			} else {
				err = hatch.CycleBrick(hatch.CycleBrickOpts{
					Brick:         slug,
					SinceSnapshot: snap,
					ResultOut:     out,
					WorkDir:       agentWorkDir,
				})
			}
			elapsed := time.Since(t0)
			if err != nil {
				results <- brickOutcome{slug: slug, err: err, elapsed: elapsed}
				return
			}

			result, rerr := hatch.LoadBrickResult(out)
			if rerr != nil {
				results <- brickOutcome{slug: slug, err: rerr, elapsed: elapsed}
				return
			}

			planMu.Lock()
			plan.Bricks[slug] = result
			planMu.Unlock()
			results <- brickOutcome{slug: slug, result: result, elapsed: elapsed}
		}()
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	counts := map[string]int{}
	var failed bool
	for o := range results {
		if o.err != nil {
			fmt.Printf("✗ dispatch: %s: %v\n", o.slug, o.err)
			counts["error"]++
			failed = true
			continue
		}
		counts[o.result.Status]++
		fmt.Printf("✓ dispatch: %s -> %s (%s)\n", o.slug, o.result.Status, o.elapsed.Round(time.Millisecond))
		if o.result.Status != "idempotent" {
			failed = true
		}
	}
	totalElapsed := time.Since(start)

	if cfg.Worktree {
		// Coord-side lane reconciliation (AIDR-00135). For each agent
		// worktree, partition the agent's diff against its brickPath:
		// in-lane edits land on the coord branch via a real three-way
		// merge (or via merge-and-revert in a temp worktree when out-
		// of-lane edits are present); out-of-lane edits get captured
		// as a sidecar patch the operator can inspect/apply elsewhere.
		mergeKeys := make([]string, 0, len(worktrees))
		for k := range worktrees {
			mergeKeys = append(mergeKeys, k)
		}
		sort.Strings(mergeKeys)
		mergedCount := 0
		sidecarCount := 0
		for _, slug := range mergeKeys {
			wt := worktrees[slug]
			brickPath := ""
			if b, ok := allBricks[slug]; ok {
				brickPath = b.Path
			}
			outcome, err := reconcileLane(context.Background(), workDir, runID, wt, brickPath)
			if err != nil {
				fmt.Printf("✗ dispatch: merge %s: %v\n", slug, err)
				failed = true
				continue
			}
			if outcome.merged {
				mergedCount++
			}
			if outcome.sidecarPath != "" {
				sidecarCount++
				planMu.Lock()
				if br, ok := plan.Bricks[slug]; ok {
					br.OutOfLanePatch = outcome.sidecarPath
					plan.Bricks[slug] = br
				}
				planMu.Unlock()
			}
		}
		if mergedCount > 0 {
			fmt.Printf("✓ dispatch: merged %d agent branch(es) back to HEAD\n", mergedCount)
		} else {
			fmt.Printf("✓ dispatch: no agent commits to merge (all worktrees clean)\n")
		}
		if sidecarCount > 0 {
			fmt.Printf("⚠ dispatch: %d agent(s) emitted out-of-lane sidecar patch(es); see plan output\n", sidecarCount)
		}
	}

	planOut := cfg.PlanOut
	if planOut == "" {
		planOut = filepath.Join(runDir, "plan.cue")
	}
	if err := hatch.WritePlanCUE(planOut, plan); err != nil {
		return 2, fmt.Errorf("write plan: %w", err)
	}

	fmt.Println()
	fmt.Printf("dispatch summary (run %s):\n", runID)
	fmt.Printf("  %d bricks dispatched in %s (parallel=%d)\n", len(bricks), totalElapsed.Round(time.Millisecond), cfg.Parallel)
	statuses := []string{"idempotent", "blocked", "dirty", "not-converged", "error"}
	for _, s := range statuses {
		if n := counts[s]; n > 0 {
			fmt.Printf("  %d %s\n", n, s)
		}
	}
	fmt.Printf("plan written to %s\n", planOut)

	// Surface resume hints for any agent that ran via ACP. The
	// session ID + log path live in the per-agent BrickResult; we
	// just stitch them into a cut-and-pasteable command line.
	resumeSlugs := make([]string, 0, len(plan.Bricks))
	for slug, br := range plan.Bricks {
		if br.SessionID != "" {
			resumeSlugs = append(resumeSlugs, slug)
		}
	}
	if len(resumeSlugs) > 0 {
		sort.Strings(resumeSlugs)
		fmt.Println()
		fmt.Println("resume any agent's session for debug:")
		for _, slug := range resumeSlugs {
			br := plan.Bricks[slug]
			fmt.Printf("  claude --resume %s   # %s (log: %s)\n", br.SessionID, slug, br.LogPath)
		}
	}

	// Surface out-of-lane sidecars (AIDR-00135). These are operator-
	// facing only; no auto-apply. The patch is anchored at the
	// agent's fork point so `git apply --3way` works against any
	// later coord state.
	sidecarSlugs := make([]string, 0, len(plan.Bricks))
	for slug, br := range plan.Bricks {
		if br.OutOfLanePatch != "" {
			sidecarSlugs = append(sidecarSlugs, slug)
		}
	}
	if len(sidecarSlugs) > 0 {
		sort.Strings(sidecarSlugs)
		fmt.Println()
		fmt.Println("out-of-lane sidecars (operator review; apply with `git apply --3way <path>`):")
		for _, slug := range sidecarSlugs {
			br := plan.Bricks[slug]
			fmt.Printf("  %s   # %s\n", br.OutOfLanePatch, slug)
		}
	}

	// Surface per-agent token usage and cost (TODO 2). Counts come
	// from the bridge's UNSTABLE PromptResponse.Usage and
	// SessionUsageUpdate streams; older bridges omit them, in
	// which case this block prints nothing.
	usageSlugs := make([]string, 0, len(plan.Bricks))
	for slug, br := range plan.Bricks {
		if br.TokensTotal > 0 || br.CostAmount > 0 {
			usageSlugs = append(usageSlugs, slug)
		}
	}
	if len(usageSlugs) > 0 {
		sort.Strings(usageSlugs)
		fmt.Println()
		fmt.Println("agent token usage (ACP UNSTABLE; missing on older bridges):")
		var (
			totIn, totOut, totCacheR, totCacheW, totThought, totAll int
			totCost                                                 float64
			currency                                                string
		)
		for _, slug := range usageSlugs {
			br := plan.Bricks[slug]
			fmt.Printf("  %s: in=%d out=%d cache_r=%d cache_w=%d thought=%d total=%d",
				slug, br.TokensInput, br.TokensOutput, br.TokensCacheRead,
				br.TokensCacheWrite, br.TokensThought, br.TokensTotal)
			if br.CostAmount > 0 {
				fmt.Printf("  cost=%.4f %s", br.CostAmount, br.CostCurrency)
			}
			fmt.Println()
			totIn += br.TokensInput
			totOut += br.TokensOutput
			totCacheR += br.TokensCacheRead
			totCacheW += br.TokensCacheWrite
			totThought += br.TokensThought
			totAll += br.TokensTotal
			totCost += br.CostAmount
			if br.CostCurrency != "" {
				currency = br.CostCurrency
			}
		}
		fmt.Printf("  total: in=%d out=%d cache_r=%d cache_w=%d thought=%d total=%d",
			totIn, totOut, totCacheR, totCacheW, totThought, totAll)
		if totCost > 0 {
			fmt.Printf("  cost=%.4f %s", totCost, currency)
		}
		fmt.Println()
	}

	if failed {
		return 1, nil
	}
	return 0, nil
}

type brickOutcome struct {
	slug    string
	result  hatch.BrickResult
	err     error
	elapsed time.Duration
}

// reconcileOutcome reports what reconcileLane did with one agent's
// branch: whether anything landed on the coord branch (merged) and
// where the out-of-lane sidecar (if any) was written, workspace-
// relative.
type reconcileOutcome struct {
	merged      bool
	sidecarPath string
}

// reconcileLane is the coord-side lane reconciliation primitive
// (AIDR-00135). It computes the agent's diff against its brick
// path, partitions the result into in-lane and out-of-lane sets,
// and dispatches to the matching merge shape:
//   - both empty   -> no-op
//   - all in-lane  -> direct MergeWorktree (today's path)
//   - all out-of-lane -> sidecar only, no merge
//   - mixed        -> sidecar + merge-and-revert in a temp worktree,
//     then merge the pruned branch back via MergeWorktree
//
// On success in the mixed/in-lane paths, returns merged=true and
// the sidecar path (workspace-relative) when a sidecar was written.
// On failure, returns the error and retains the merge worktree
// (per AIDR-00135 Q4 cleanup policy).
func reconcileLane(ctx context.Context, workDir, runID string, wt *Worktree, brickPath string) (reconcileOutcome, error) {
	out := reconcileOutcome{}
	paths, err := LaneDiff(ctx, workDir, wt.Base, wt.Branch)
	if err != nil {
		return out, err
	}
	if len(paths) == 0 {
		return out, nil
	}
	inLane, outOfLane := LanePartition(paths, brickPath)

	sidecarRel := ""
	if len(outOfLane) > 0 {
		sidecarRel = filepath.Join(".defn", "dispatch", runID, "out_of_lane", wt.Slug+".patch")
		dest := filepath.Join(workDir, sidecarRel)
		if err := WriteSidecarPatch(ctx, workDir, wt.Base, wt.Branch, outOfLane, dest); err != nil {
			return out, err
		}
		out.sidecarPath = sidecarRel
	}

	switch {
	case len(inLane) == 0:
		// All-out-of-lane: nothing to merge; sidecar is the only
		// artifact. Caller leaves the agent branch in place; run
		// cleanup teardown removes it.
		return out, nil

	case len(outOfLane) == 0:
		// All-in-lane: today's MergeWorktree is mathematically the
		// same as a merge-and-revert with nothing to revert, but
		// avoids spawning the temp worktree.
		if err := MergeWorktree(ctx, workDir, wt); err != nil {
			return out, err
		}
		out.merged = true
		return out, nil

	default:
		// Mixed: spawn a merge worktree off the current coord HEAD,
		// run merge-and-revert, then merge the pruned branch back.
		coordHEAD, err := gitRevParse(ctx, workDir, "HEAD")
		if err != nil {
			return out, err
		}
		mergeWT, err := CreateMergeWorktree(ctx, workDir, runID, wt.Slug, coordHEAD)
		if err != nil {
			return out, err
		}
		if err := MergeAndRevert(ctx, mergeWT, wt.Branch, outOfLane); err != nil {
			// Retain merge worktree for inspection.
			return out, fmt.Errorf("merge-and-revert %s: %w", wt.Slug, err)
		}
		if err := MergeWorktree(ctx, workDir, mergeWT); err != nil {
			return out, fmt.Errorf("merge pruned branch %s: %w", mergeWT.Branch, err)
		}
		// Success: tear down the merge worktree + branch.
		_ = RemoveWorktree(ctx, workDir, mergeWT)
		out.merged = true
		return out, nil
	}
}

func clonePlan(p *hatch.DispatchPlan) *hatch.DispatchPlan {
	out := &hatch.DispatchPlan{Bricks: make(map[string]hatch.BrickResult, len(p.Bricks))}
	keys := make([]string, 0, len(p.Bricks))
	for k := range p.Bricks {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		out.Bricks[k] = p.Bricks[k]
	}
	return out
}
