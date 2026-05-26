package version

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"
)

// Version is set at build time via ldflags.
var Version = "dev"

// Config holds configuration for the version command.
type Config struct {
	Version string
}

// Service implements ServiceRunner for the version command.
type Service struct{}

// NewService creates a new version service.
func NewService() *Service { return &Service{} }

// Run prints the version and returns.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	fmt.Printf("defn v%s\n", cfg.Version)
	return nil
}

// Stop is a no-op for the version command.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles the command configuration from cobra flags and args.
func MakeConfig(_ *cobra.Command, _ []string) Config {
	return Config{Version: Version}
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(_ *cobra.Command) {}
