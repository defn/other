package gen

import (
	"context"
	"fmt"
	"sync"

	"github.com/defn/other/m/tenant/library/go/lib/cli"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/app"
	"github.com/defn/other/m/tenant/library/go/lib/gen/awsconfig"
	"github.com/defn/other/m/tenant/library/go/lib/gen/awstofu"
	"github.com/defn/other/m/tenant/library/go/lib/gen/cuetree"
	"github.com/defn/other/m/tenant/library/go/lib/gen/discordbot"
	"github.com/defn/other/m/tenant/library/go/lib/gen/dispatchworker"
	"github.com/defn/other/m/tenant/library/go/lib/gen/env"
	genfmt "github.com/defn/other/m/tenant/library/go/lib/gen/fmt"
	"github.com/defn/other/m/tenant/library/go/lib/gen/gmailbot"
	"github.com/defn/other/m/tenant/library/go/lib/gen/gocmd"
	"github.com/defn/other/m/tenant/library/go/lib/gen/gocmdcue"
	"github.com/defn/other/m/tenant/library/go/lib/gen/gocmdparent"
	"github.com/defn/other/m/tenant/library/go/lib/gen/golib"
	"github.com/defn/other/m/tenant/library/go/lib/gen/image"
	"github.com/defn/other/m/tenant/library/go/lib/gen/infra"
	"github.com/defn/other/m/tenant/library/go/lib/gen/k3d"
	"github.com/defn/other/m/tenant/library/go/lib/gen/k8s"
	"github.com/defn/other/m/tenant/library/go/lib/gen/matrixbot"
	"github.com/defn/other/m/tenant/library/go/lib/gen/misetoml"
	"github.com/defn/other/m/tenant/library/go/lib/gen/modulebazel"
	"github.com/defn/other/m/tenant/library/go/lib/gen/oci"
	"github.com/defn/other/m/tenant/library/go/lib/gen/operatorcrds"
	"github.com/defn/other/m/tenant/library/go/lib/gen/restamp"
	"github.com/defn/other/m/tenant/library/go/lib/gen/seed"
	"github.com/defn/other/m/tenant/library/go/lib/gen/skill"
	"github.com/defn/other/m/tenant/library/go/lib/gen/slackbot"
	"github.com/defn/other/m/tenant/library/go/lib/gen/speclattice"
	"github.com/defn/other/m/tenant/library/go/lib/gen/telegrambot"
	"github.com/defn/other/m/tenant/library/go/lib/gen/versionsbzl"
	"github.com/defn/other/m/tenant/library/go/lib/log"
	"github.com/spf13/cobra"
	"go.uber.org/fx"
)

// Phase A generators -- run in parallel, independent of each other.
var phaseA = []struct {
	name string
	fn   func(*gen.Context) error
}{
	{"mise-toml", misetoml.Run},
	{"module-bazel", modulebazel.Run},
	{"k3d", k3d.Run},
	{"oci", oci.Run},
	{"image", image.Run},
	{"versions-bzl", versionsbzl.Run},
	{"app", app.Run},
	{"k8s", k8s.Run},
	{"env", env.Run},
	{"infra", infra.Run},
	{"aws-tofu", awstofu.Run},
	{"aws-config", awsconfig.Run},
	{"fmt", genfmt.Run},
	{"go-cmd", gocmd.Run},
	{"go-cmd-cue", gocmdcue.Run},
	{"go-cmd-parent", gocmdparent.Run},
	{"go-lib", golib.Run},
	{"slack-bot", slackbot.Run},
	{"discord-bot", discordbot.Run},
	{"gmail-bot", gmailbot.Run},
	{"matrix-bot", matrixbot.Run},
	{"telegram-bot", telegrambot.Run},
	{"skill", skill.Run},
	{"operator-crds", operatorcrds.Run},
	{"restamp", restamp.Run},
	// NOTE: dispatch-worker is intentionally NOT here. It reads brick
	// SOURCE DIRS produced by the generators above (infra/app/k8s create
	// tenant/<t>/infra/global, var/app/..., etc.) and writes a
	// dispatch.cue only into dirs that already exist on disk. In the
	// parallel phase its os.Stat(brickdir) races those dirs' creation, so
	// for a FRESH fork (dirs not yet committed) the dispatch.cue is
	// nondeterministically skipped -- the cold-CI "clean outside var/"
	// drift (AIDR-00151). It runs sequentially after Phase A instead.
}

// PhaseAByContractName maps the contract `generator:` field (which
// matches the generator's source-dir name under go/lib/gen/<name>)
// to its Run function. Per-brick hatch (AIDR-00132 step 6) inverts
// the contracts' `generators.<name>.paths` index against a brick's
// path prefix to pick a subset to run; this map is the resolution
// table from contract name -> runnable.
//
// Aggregator generators (lattice, cuetree, speclattice, buildsync,
// seed) are intentionally absent. AIDR-00132 says lattice + manifest
// + cross-brick buildsync run once at the coordinator's merge
// boundary, not per dispatch. seed is a pre-phase chart-digest
// fetch with no per-brick story. If a future brick legitimately
// needs one of these, add it here and update the AIDR exclusion
// list.
var PhaseAByContractName = map[string]func(*gen.Context) error{
	"misetoml":       misetoml.Run,
	"modulebazel":    modulebazel.Run,
	"k3d":            k3d.Run,
	"oci":            oci.Run,
	"image":          image.Run,
	"versionsbzl":    versionsbzl.Run,
	"app":            app.Run,
	"k8s":            k8s.Run,
	"infra":          infra.Run,
	"awstofu":        awstofu.Run,
	"awsconfig":      awsconfig.Run,
	"fmt":            genfmt.Run,
	"gocmd":          gocmd.Run,
	"gocmdcue":       gocmdcue.Run,
	"gocmdparent":    gocmdparent.Run,
	"golib":          golib.Run,
	"slackbot":       slackbot.Run,
	"discordbot":     discordbot.Run,
	"gmailbot":       gmailbot.Run,
	"matrixbot":      matrixbot.Run,
	"telegrambot":    telegrambot.Run,
	"skill":          skill.Run,
	"operatorcrds":   operatorcrds.Run,
	"restamp":        restamp.Run,
	"dispatchworker": dispatchworker.Run,
}

// ModuleOptions returns fx providers for the gen parent command.
func ModuleOptions() fx.Option {
	return fx.Options(
		fx.Provide(
			func() *cli.Latch[Config] { return cli.NewLatch[Config]() },
			NewService,
			func(latch *cli.Latch[Config], svc *Service) *cli.Managed[Config] {
				return cli.NewManaged(latch, svc, log.Logger().Named("gen"))
			},
		),
		fx.Invoke(func(m *cli.Managed[Config], lc fx.Lifecycle) {
			m.RegisterLifecycle(lc)
		}),
	)
}

// NewGenContext creates a gen.Context for generator execution.
// Called lazily at run time, not at fx startup.
func NewGenContext() (*gen.Context, error) {
	return gen.NewContext(".", log.Logger().Named("gen"))
}

// NewGenContextAt is like NewGenContext but pinned to an explicit
// workspace root rather than cwd. The per-brick hatch dispatcher
// (AIDR-00132) uses this so a coordinator-supplied --work-dir
// (e.g., a git worktree path) drives gen catalog/schema loads
// without first chdir'ing the process.
func NewGenContextAt(workDir string) (*gen.Context, error) {
	return gen.NewContext(workDir, log.Logger().Named("gen"))
}

// Config holds configuration for the gen command (default action: run all).
type Config struct{}

// Service implements ServiceRunner for the gen default action (full pipeline).
type Service struct{}

// NewService creates a new gen service.
func NewService() *Service {
	return &Service{}
}

// Run executes the full generation pipeline.
func (s *Service) Run(_ context.Context, _ Config, onReady func(error)) error {
	onReady(nil)
	genCtx, err := NewGenContext()
	if err != nil {
		return fmt.Errorf("init gen context: %w", err)
	}
	return RunFullPipeline(genCtx)
}

// RunFullPipeline executes the full generation pipeline (all phases).
func RunFullPipeline(ctx *gen.Context) error {
	// Pre-phase 0: seed chart digests
	if err := seed.Run(ctx); err != nil {
		return fmt.Errorf("seed: %w", err)
	}

	// Phase A: independent generators in parallel
	var wg sync.WaitGroup
	errs := make([]error, len(phaseA))
	for i, g := range phaseA {
		wg.Add(1)
		go func(idx int, name string, fn func(*gen.Context) error) {
			defer wg.Done()
			if err := fn(ctx); err != nil {
				errs[idx] = fmt.Errorf("gen %s: %w", name, err)
			}
		}(i, g.name, g.fn)
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return err
		}
	}
	// Phase A.5: dispatch-worker. Sequential, AFTER Phase A, because it
	// stamps a dispatch.cue into every brick whose source dir exists on
	// disk -- and those dirs are created by the Phase A generators
	// (infra/app/k8s/...). Run in parallel it raced their creation and
	// skipped freshly-generated bricks nondeterministically, leaving an
	// uncommitted dispatch.cue to surface on the next pass (the fork
	// cold-CI "clean outside var/" drift, AIDR-00151). Sequencing it here
	// makes "source dir is real" a decision over Phase A's final state.
	if err := dispatchworker.Run(ctx); err != nil {
		return fmt.Errorf("gen dispatch-worker: %w", err)
	}
	// Stage new files so git ls-files sees them in Phase B
	if err := ctx.GitAddAll(); err != nil {
		return fmt.Errorf("git add: %w", err)
	}
	// Phase B: CUE tree (needs all generated files to exist)
	if err := cuetree.Run(ctx); err != nil {
		return fmt.Errorf("cue-tree: %w", err)
	}
	if err := ctx.CueFmt("var/gen-manifest.cue"); err != nil {
		return fmt.Errorf("cue fmt manifest: %w", err)
	}

	// Phase C: spec lattice (reads file tree, returns in-memory tree)
	specTree, err := speclattice.Run(ctx)
	if err != nil {
		return fmt.Errorf("spec-lattice: %w", err)
	}
	ctx.SpecTree = specTree.ToMap()
	if err := ctx.CueFmt("var/gen-lattice.cue"); err != nil {
		return fmt.Errorf("cue fmt lattice: %w", err)
	}

	// Validate manifest schema (loads ./manifest which unifies gen-manifest.cue
	// with manifest.cue's closed structs). This replaces the separate
	// check-manifest CUE eval.
	//
	// gen-manifest.cue + gen-lattice.cue now live in var/ and reach the
	// manifest/spec packages via the gen var overlay, which was
	// snapshotted at NewContext before cuetree/speclattice rewrote them.
	// Refresh so this validation sees the freshly-generated tree
	// (AIDR-00145 D5.1).
	if err := ctx.RefreshOverlay(); err != nil {
		return fmt.Errorf("refresh overlay: %w", err)
	}
	if _, err := ctx.LoadCUEPackage("./kernel/manifest", nil); err != nil {
		return fmt.Errorf("manifest validation: %w", err)
	}
	ctx.LogOK(fmt.Sprintf("all %d git-tracked files are in CUE manifest", ctx.GitFileCount))
	// Final stage
	return ctx.GitAddAll()
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles the command configuration.
func MakeConfig(_ *cobra.Command, _ []string) Config {
	return Config{}
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(_ *cobra.Command) {}
