// Package miseupgrade hatches a mise tool upgrade to equilibrium.
// After mise upgrade --bump has been run and versions.cue patched,
// this command hatches the workspace to a consistent, validated state.
//
// With no args, shows available tool upgrades via mise outdated.
// With tool args, runs mise upgrade --bump for those tools, then
// hatches to equilibrium.
package miseupgrade

import (
	"context"
	"fmt"

	hatchlib "github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
	"github.com/spf13/cobra"
)

type Config struct {
	Tools []string
}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)

	if len(cfg.Tools) == 0 {
		return showAvailable()
	}

	return upgradeAndHatch(cfg.Tools)
}

func upgradeAndHatch(tools []string) error {
	// Run mise upgrade --bump for the selected tools.
	args := append([]string{"mise", "upgrade", "--bump"}, tools...)
	fmt.Printf("\u2713 running mise upgrade --bump %v...\n", tools)
	if err := runner.Run(context.Background(), runner.Opts{Args: args}); err != nil {
		return fmt.Errorf("mise upgrade: %w", err)
	}

	// Hatch to equilibrium.
	fmt.Println("\u2713 hatching to equilibrium...")
	if _, err := hatchlib.Cycle(); err != nil {
		return fmt.Errorf("hatch cycle: %w", err)
	}

	// Validate.
	fmt.Println("\u2713 validating...")
	if err := hatchlib.CycleAndValidate(); err != nil {
		return fmt.Errorf("validate: %w", err)
	}

	return nil
}

func showAvailable() error {
	fmt.Println("=== available mise tool upgrades ===")
	fmt.Println()

	// mise outdated exits non-zero when tools are outdated; ignore the exit code.
	_ = runner.Run(context.Background(), runner.Opts{Args: []string{"mise", "outdated"}})

	fmt.Println()
	fmt.Println("usage: defn hatch miseupgrade <tool> [tool...]")
	return nil
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, args []string) Config {
	return Config{Tools: args}
}

func RegisterFlags(_ *cobra.Command) {}
