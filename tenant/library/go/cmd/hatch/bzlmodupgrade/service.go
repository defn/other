// Package bzlmodupgrade hatches a Bazel module upgrade to equilibrium.
// After versions.cue has been patched with new module versions from BCR,
// this command hatches the workspace to a consistent, validated state.
//
// Note: bzlmod upgrades can change tool constraints (e.g. upgrading
// rules_uv changes the bundled uv version). Run hatch miseupgrade
// after bzlmodupgrade when Bazel modules with tool constraints change.
package bzlmodupgrade

import (
	"context"
	"fmt"

	hatchlib "github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/spf13/cobra"
)

type Config struct{}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, _ Config, onReady func(error)) error {
	onReady(nil)
	return run()
}

func run() error {
	// Hatch to equilibrium with new Bazel module versions.
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

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, _ []string) Config { return Config{} }

func RegisterFlags(_ *cobra.Command) {}
