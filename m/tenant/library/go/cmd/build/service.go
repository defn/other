package build

import (
	"context"
	"fmt"
	"os"

	"github.com/defn/other/m/v/buildkite--agent/clicommand"
	"github.com/defn/other/m/v/buildkite--agent/version"
	"github.com/spf13/cobra"
	urfavecli "github.com/urfave/cli"
)

// Config holds the raw args to pass through to the urfave/cli agent.
type Config struct {
	Args []string
}

// Service delegates to the buildkite agent urfave/cli app.
type Service struct{}

// NewService creates a new build service.
func NewService() *Service { return &Service{} }

// Run executes the urfave/cli agent app with the given args.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)

	app := urfavecli.NewApp()
	app.Name = "defn build"
	app.Version = version.Version()
	app.Commands = clicommand.BuildkiteAgentCommands
	app.ErrWriter = os.Stderr
	app.CommandNotFound = func(c *urfavecli.Context, command string) {
		fmt.Fprintf(app.ErrWriter, "defn build: unknown subcommand %q\n", command)
		fmt.Fprintf(app.ErrWriter, "Run 'defn build --help' for usage.\n")
	}

	return app.Run(append([]string{"defn-build"}, cfg.Args...))
}

// Stop is a no-op for the build command.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig captures args to pass through to urfave/cli.
func MakeConfig(_ *cobra.Command, args []string) Config {
	return Config{Args: args}
}

// RegisterFlags sets DisableFlagParsing so all args pass through to urfave/cli.
func RegisterFlags(cmd *cobra.Command) {
	cmd.DisableFlagParsing = true
}
