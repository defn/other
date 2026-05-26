package root

import (
	"github.com/spf13/cobra"
	"go.uber.org/fx"
)

// Module provides the root cobra command.
var Module = fx.Module("root",
	fx.Provide(NewCommand),
)

// NewCommand creates the root cobra command.
func NewCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:           "defn",
		Short:         "defn CLI",
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	return cmd
}
