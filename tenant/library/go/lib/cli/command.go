package cli

import "github.com/spf13/cobra"

// Command is implemented by every subcommand module.
type Command interface {
	// GetCommand returns the cobra command for this subcommand.
	GetCommand() *cobra.Command
}
