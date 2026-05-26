package gocmd

import (
	"context"
	"os"

	stamplib "github.com/defn/other/m/tenant/library/go/lib/stamp"
	"github.com/spf13/cobra"
)

// Config holds configuration for the go-cmd stamp subcommand.
type Config struct {
	Path string
	Desc string
}

// Service implements ServiceRunner for stamping go-cmd bricks.
type Service struct{}

// NewService creates a new service.
func NewService() *Service { return &Service{} }

// Run stamps a go-cmd brick.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	rootDir, _ := os.Getwd()
	return stamplib.StampBrick(rootDir, "go-cmd", cfg.Path, cfg.Desc)
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles configuration from cobra flags and args.
func MakeConfig(_ *cobra.Command, args []string) Config {
	cfg := Config{}
	if len(args) > 0 {
		cfg.Path = args[0]
	}
	return cfg
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(_ *cobra.Command) {}
