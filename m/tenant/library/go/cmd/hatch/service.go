// Package hatch provides the hatch parent command.
//
// `defn hatch` brings the workspace to a consistent state after changes:
// gen + build (no tests) + sync. It breaks chicken-and-egg cycles where
// tests fail on files that gen needs to regenerate.
//
// When to use hatch vs gen vs check:
//
//   - mise run hatch -- after any change that affects BUILD files,
//     chart versions, or other generated files. Safe to run repeatedly.
//   - mise run gen   -- full pipeline with tests and validation. Run
//     after hatch to verify everything is correct.
//   - mise run check -- like gen but also verifies clean git state.
//
// Subcommands encode domain-specific knowledge for a type of change:
//
//   - defn hatch                       -- bare equilibrium (gen + build + sync).
//   - defn hatch helmupgrade <app>     -- helm chart upgrade: hatch +
//     detect image registry changes + fix app.cue/mirrors.cue + re-hatch.
//   - defn hatch goupgrade             -- go mod tidy + hatch + validate.
//   - defn hatch bzlmodupgrade         -- hatch + validate after BCR
//     version patches.
//   - defn hatch miseupgrade [tool]    -- show outdated / upgrade tool +
//     hatch + validate.
//
// `mise run upgrade <kind>` is the typical entry point; it does
// discovery (online) and delegates to the corresponding hatch
// subcommand for offline equilibrium.
package hatch

import (
	"context"

	"github.com/defn/other/m/tenant/library/go/lib/cli"
	hatchlib "github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/defn/other/m/tenant/library/go/lib/log"
	"github.com/spf13/cobra"
	"go.uber.org/fx"
)

type Config struct {
	Once bool

	// Per-brick equilibrium primitive (AIDR-00132 F1).
	Brick         string
	SinceSnapshot string
	ResultOut     string
}

type Service struct{}

func NewService() *Service { return &Service{} }

// Run executes a hatch loop to idempotence by default. With --once,
// runs a single pass (debugging / mid-cascade inspection). With
// --brick, runs the AIDR-00132 per-brick equilibrium primitive
// (CycleBrick) instead of whole-workspace Cycle.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	if cfg.Brick != "" {
		return hatchlib.CycleBrick(hatchlib.CycleBrickOpts{
			Brick:         cfg.Brick,
			SinceSnapshot: cfg.SinceSnapshot,
			ResultOut:     cfg.ResultOut,
		})
	}
	if cfg.Once {
		_, err := hatchlib.CycleOnce()
		return err
	}
	_, err := hatchlib.Cycle()
	return err
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(cmd *cobra.Command, _ []string) Config {
	once, _ := cmd.Flags().GetBool("once")
	brick, _ := cmd.Flags().GetString("brick")
	since, _ := cmd.Flags().GetString("since-snapshot")
	resultOut, _ := cmd.Flags().GetString("result-out")
	return Config{Once: once, Brick: brick, SinceSnapshot: since, ResultOut: resultOut}
}

func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().Bool("once", false, "Run a single hatch pass instead of looping to idempotence")
	cmd.Flags().String("brick", "", "Per-brick equilibrium: slug-or-path of the brick to converge (AIDR-00132)")
	cmd.Flags().String("since-snapshot", "", "Path to a CUE #DispatchPlan describing writes-completed-since-dispatch (AIDR-00132 F1)")
	cmd.Flags().String("result-out", "", "Path to write the per-brick #BrickResult CUE")
}

// ModuleOptions returns fx options for the parent command's service wiring.
func ModuleOptions() fx.Option {
	return fx.Options(
		fx.Provide(
			func() *cli.Latch[Config] { return cli.NewLatch[Config]() },
			NewService,
			func(latch *cli.Latch[Config], svc *Service) *cli.Managed[Config] {
				return cli.NewManaged(latch, svc, log.Logger().Named("hatch"))
			},
		),
		fx.Invoke(func(m *cli.Managed[Config], lc fx.Lifecycle) {
			m.RegisterLifecycle(lc)
		}),
	)
}
