package sync

import (
	"context"
	"fmt"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/buildsync"
	"github.com/defn/other/m/tenant/library/go/lib/log"
	"github.com/spf13/cobra"
)

// Config holds configuration for the sync command.
type Config struct{}

// Service implements ServiceRunner for the sync command.
type Service struct{}

// NewService creates a new sync service.
func NewService() *Service { return &Service{} }

// Run builds Bazel targets and syncs outputs to workspace.
func (s *Service) Run(_ context.Context, _ Config, onReady func(error)) error {
	onReady(nil)

	ctx, err := gen.NewContext(".", log.Logger().Named("sync"))
	if err != nil {
		return fmt.Errorf("init gen context: %w", err)
	}

	// Build and sync
	if err := buildsync.Run(ctx); err != nil {
		return fmt.Errorf("build-sync: %w", err)
	}

	// Bulk format
	if err := bulkFormat(ctx); err != nil {
		return fmt.Errorf("bulk format: %w", err)
	}

	// Stage synced files
	return ctx.GitAddAll()
}

func bulkFormat(ctx *gen.Context) error {
	tfOut, err := ctx.Sh("git", "ls-files", "--", "*.tf")
	if err != nil {
		return err
	}
	var tfFiles []string
	for _, f := range strings.Split(tfOut, "\n") {
		if f != "" {
			tfFiles = append(tfFiles, f)
		}
	}
	if len(tfFiles) > 0 {
		args := append([]string{"tofu", "fmt"}, tfFiles...)
		if err := ctx.MiseExec("opentofu", args...); err != nil {
			return fmt.Errorf("tofu fmt: %w", err)
		}
	}

	tvOut, err := ctx.Sh("git", "ls-files", "--", "*.tfvars.json")
	if err != nil {
		return err
	}
	var tvFiles []string
	for _, f := range strings.Split(tvOut, "\n") {
		if f != "" {
			tvFiles = append(tvFiles, f)
		}
	}
	if len(tvFiles) > 0 {
		args := append([]string{"biome", "format", "--write"}, tvFiles...)
		if err := ctx.MiseExec("biome", args...); err != nil {
			return fmt.Errorf("biome format: %w", err)
		}
	}
	return nil
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles the command configuration.
func MakeConfig(_ *cobra.Command, _ []string) Config {
	return Config{}
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(_ *cobra.Command) {}
