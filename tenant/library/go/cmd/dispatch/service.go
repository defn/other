// Package dispatch provides the parallel coordinator command.
//
// `defn dispatch` walks a brick set in (catalog or argv) order,
// invokes `defn hatch --brick=<slug>` (in-process) for each, and
// accumulates the per-brick #BrickResult values into a running
// #DispatchPlan. The CUE schema substrate at
// m/kernel/spec/dispatch/dispatch_plan.cue is the wire format.
//
// The default --parallel=1 implements the AIDR-00133 sequential
// stub. --parallel=K demonstrates the AIDR-00132 motivation:
// scaling out small humans onto K parallel sub-agents. Per-brick
// isolation is the safety contract; AIDR-00098's pairwise-write vet
// proves no two bricks in the same wave write to the same path.
package dispatch

import (
	"context"
	"strings"

	dispatchlib "github.com/defn/other/m/tenant/library/go/lib/dispatch"
	"github.com/spf13/cobra"
)

// Config holds configuration for the dispatch command.
type Config struct {
	Target    string
	Bricks    []string
	All       bool
	Parallel  int
	PlanOut   string
	PlanOnly  bool
	Worktree  bool
	ACPPrompt string
	ACPBridge []string
	PlansDir  string
}

// Service implements ServiceRunner.
type Service struct{}

// NewService creates a new service.
func NewService() *Service { return &Service{} }

// Run executes one dispatch round.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	_, err := dispatchlib.Run(dispatchlib.Config{
		Target:    cfg.Target,
		Bricks:    cfg.Bricks,
		All:       cfg.All,
		Parallel:  cfg.Parallel,
		PlanOut:   cfg.PlanOut,
		PlanOnly:  cfg.PlanOnly,
		Worktree:  cfg.Worktree,
		ACPPrompt: cfg.ACPPrompt,
		ACPBridge: cfg.ACPBridge,
		PlansDir:  cfg.PlansDir,
	})
	return err
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles configuration from cobra flags and args.
func MakeConfig(cmd *cobra.Command, _ []string) Config {
	target, _ := cmd.Flags().GetString("target")
	bricks, _ := cmd.Flags().GetString("bricks")
	all, _ := cmd.Flags().GetBool("all")
	parallel, _ := cmd.Flags().GetInt("parallel")
	planOut, _ := cmd.Flags().GetString("plan-out")
	planOnly, _ := cmd.Flags().GetBool("plan-only")
	worktree, _ := cmd.Flags().GetBool("worktree")
	acpPrompt, _ := cmd.Flags().GetString("acp-prompt")
	acpBridge, _ := cmd.Flags().GetStringSlice("acp-bridge")
	plansDir, _ := cmd.Flags().GetString("plans-dir")
	var bs []string
	for _, b := range strings.Split(bricks, ",") {
		b = strings.TrimSpace(b)
		if b != "" {
			bs = append(bs, b)
		}
	}
	return Config{
		Target:    target,
		Bricks:    bs,
		All:       all,
		Parallel:  parallel,
		PlanOut:   planOut,
		PlanOnly:  planOnly,
		Worktree:  worktree,
		ACPPrompt: acpPrompt,
		ACPBridge: acpBridge,
		PlansDir:  plansDir,
	}
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("target", "", "Coordinator-first: pick one brick; the planner computes the involved set (path-overlapping siblings)")
	cmd.Flags().String("bricks", "", "Explicit slug list (escape hatch for tests / dev iteration)")
	cmd.Flags().Bool("all", false, "Dispatch every component brick (slug-sorted)")
	cmd.Flags().Int("parallel", 1, "Maximum in-flight dispatches (1 = sequential AIDR-00133 stub)")
	cmd.Flags().String("plan-out", "", "Path to write the final #DispatchPlan CUE; default: .defn/dispatch/<run-id>/plan.cue")
	cmd.Flags().Bool("plan-only", false, "Compute the partition (shared bricks + disjoint sub-agent groups) and exit; do not run any agents")
	cmd.Flags().Bool("worktree", false, "Spawn one git worktree per agent (branched from HEAD); merge agent branches back at end (F2 isolation contract)")
	cmd.Flags().String("acp-prompt", "", "Prompt template for ACP-based agent (Claude Code via @zed-industries/claude-agent-acp). Placeholders: {{slug}}, {{worktree}}, {{run}}, {{plans_dir}}. Requires --worktree. Example: 'use the sp-bricks skill on {{plans_dir}}/{{slug}}.md'")
	cmd.Flags().StringSlice("acp-bridge", nil, "ACP bridge command (default: 'claude-agent-acp', the mise-pinned shim from kernel/schema/versions.cue). Override only if you need a different bridge.")
	cmd.Flags().String("plans-dir", "", "Stable directory holding pre-authored per-brick plan files (.md). Decoupled from --run-id so plans can be authored once and reused. Default: <workspace>/.defn/dispatch/plans. Substituted into --acp-prompt as {{plans_dir}}.")
}
