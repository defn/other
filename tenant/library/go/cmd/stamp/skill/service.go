package skill

import (
	"context"
	"os"

	stamplib "github.com/defn/other/m/tenant/library/go/lib/stamp"
	"github.com/spf13/cobra"
)

// Config holds configuration for the skill stamp subcommand.
type Config struct {
	Name    string
	Desc    string
	Subdirs []string
}

// Service implements ServiceRunner for stamping skill bricks.
type Service struct{}

// NewService creates a new service.
func NewService() *Service { return &Service{} }

// Run stamps a skill brick.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	rootDir, _ := os.Getwd()
	return stamplib.StampSkill(rootDir, cfg.Name, cfg.Desc, cfg.Subdirs)
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles configuration from cobra flags and args.
func MakeConfig(cmd *cobra.Command, args []string) Config {
	cfg := Config{}
	if len(args) > 0 {
		cfg.Name = args[0]
	}
	cfg.Desc, _ = cmd.Flags().GetString("desc")
	cfg.Subdirs, _ = cmd.Flags().GetStringSlice("subdirs")
	return cfg
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("desc", "", "skill description (required)")
	cmd.Flags().StringSlice("subdirs", nil, "helper subdirs to enable: scripts,references,prompts,examples")
}
