package tenant

import (
	"context"
	"fmt"
	"os"

	stamplib "github.com/defn/other/m/tenant/library/go/lib/stamp"
	"github.com/spf13/cobra"
)

// Config holds configuration for the tenant stamp subcommand.
type Config struct {
	Name string
	Root string
}

// Service implements ServiceRunner for stamping a tenant skeleton.
type Service struct{}

// NewService creates a new service.
func NewService() *Service { return &Service{} }

// Run stamps the universal-identity scaffolding for a tenant. See
// stamplib.StampTenant for the file set and AIDR-00071 for the
// kernel/tenant decoupling that makes the universal-identity
// approach work.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	if cfg.Name == "" {
		return fmt.Errorf("usage: defn stamp tenant <name>")
	}
	rootDir := cfg.Root
	if rootDir == "" {
		rootDir, _ = os.Getwd()
	}
	return stamplib.StampTenant(rootDir, cfg.Name)
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles configuration from cobra flags and args.
func MakeConfig(cmd *cobra.Command, args []string) Config {
	root, _ := cmd.Flags().GetString("root")
	cfg := Config{Root: root}
	if len(args) > 0 {
		cfg.Name = args[0]
	}
	return cfg
}

// RegisterFlags registers command-specific flags. --root pins the
// workspace root so callers (notably sandbox-based sh_tests) don't
// have to cd into the target tree. Defaults to cwd when unset.
func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("root", "", "workspace root under which tenant/<name>/ is stamped (default: cwd)")
}
