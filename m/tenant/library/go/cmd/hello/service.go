package hello

import (
	"context"
	"fmt"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"github.com/spf13/cobra"
)

// Config holds configuration for the hello command.
type Config struct {
	Message string
}

// Service implements ServiceRunner for the hello command.
type Service struct{}

// NewService creates a new hello service.
func NewService() *Service { return &Service{} }

// Run validates and prints the greeting.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)

	// Validate the message against the embedded CUE schema.
	ctx := cuecontext.New()
	schema := ctx.CompileString(SchemaCUE)
	val := ctx.Encode(map[string]any{"message": cfg.Message})
	if err := schema.LookupPath(cue.ParsePath("#Hello")).Unify(val).Validate(cue.Concrete(true)); err != nil {
		return fmt.Errorf("schema validation failed: %w", err)
	}

	fmt.Println(cfg.Message)
	return nil
}

// Stop is a no-op for the hello command.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles the command configuration from cobra flags and args.
func MakeConfig(cmd *cobra.Command, _ []string) Config {
	msg, _ := cmd.Flags().GetString("message")
	return Config{Message: msg}
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("message", "Hello, world!", "Message to validate and print")
}
