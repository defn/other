// Package goupgrade hatches a Go dependency upgrade to equilibrium.
// After go get -u has been run, this command tidies the module and
// hatches the workspace to a consistent, validated state.
package goupgrade

import (
	"context"
	"fmt"
	"os"

	hatchlib "github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
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
	// Tidy go modules.
	fmt.Println("\u2713 running go mod tidy...")
	wd, _ := os.Getwd()
	if err := runner.Run(context.Background(), runner.Opts{
		Args: []string{"go", "mod", "tidy"},
		Dir:  wd,
	}); err != nil {
		return fmt.Errorf("go mod tidy: %w", err)
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

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, _ []string) Config { return Config{} }

func RegisterFlags(_ *cobra.Command) {}
