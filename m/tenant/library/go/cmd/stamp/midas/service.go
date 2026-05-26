package midas

import (
	"context"
	"os"

	stamplib "github.com/defn/other/m/tenant/library/go/lib/stamp"
	"github.com/spf13/cobra"
)

// Config holds configuration for the midas stamp subcommand.
type Config struct {
	TypeName string
	Desc     string
}

// Service implements ServiceRunner for stamping Midas interfaces.
type Service struct{}

// NewService creates a new service.
func NewService() *Service { return &Service{} }

// Run stamps a complete Midas interface chain.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	rootDir, _ := os.Getwd()
	return stamplib.StampMidas(rootDir, cfg.TypeName, cfg.Desc)
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles configuration from cobra flags and args.
func MakeConfig(cmd *cobra.Command, args []string) Config {
	cfg := Config{}
	if len(args) > 0 {
		cfg.TypeName = args[0]
	}
	cfg.Desc, _ = cmd.Flags().GetString("desc")
	return cfg
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("desc", "", "description for the interface")
}
