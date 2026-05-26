package helmapp

import (
	"context"
	"os"

	stamplib "github.com/defn/other/m/tenant/library/go/lib/stamp"
	"github.com/spf13/cobra"
)

// Config holds configuration for the helm-app stamp subcommand.
type Config struct {
	Name         string
	ChartRepo    string
	ChartName    string
	ChartVersion string
	Desc         string
}

// Service implements ServiceRunner for stamping helm-app bricks.
type Service struct{}

// NewService creates a new service.
func NewService() *Service { return &Service{} }

// Run stamps a helm-app.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	rootDir, _ := os.Getwd()
	return stamplib.StampHelmApp(rootDir, stamplib.HelmAppConfig{
		Name:         cfg.Name,
		ChartRepo:    cfg.ChartRepo,
		ChartName:    cfg.ChartName,
		ChartVersion: cfg.ChartVersion,
		Desc:         cfg.Desc,
	})
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles configuration from cobra flags and args.
func MakeConfig(cmd *cobra.Command, args []string) Config {
	cfg := Config{}
	if len(args) > 0 {
		cfg.Name = args[0]
	}
	cfg.ChartRepo, _ = cmd.Flags().GetString("chart-repo")
	cfg.ChartName, _ = cmd.Flags().GetString("chart-name")
	cfg.ChartVersion, _ = cmd.Flags().GetString("chart-version")
	cfg.Desc, _ = cmd.Flags().GetString("desc")
	return cfg
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("chart-repo", "", "Helm chart repository URL")
	cmd.Flags().String("chart-name", "", "Helm chart name")
	cmd.Flags().String("chart-version", "", "Helm chart version")
	cmd.Flags().String("desc", "", "App description")
}
