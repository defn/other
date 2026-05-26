// Package app -- fork namesake CLI entry. Identical to defn's app
// wrapper at tenant/defn/go/cmd/defn/app/app.go; stampForkTenant
// stamps this seed so the fork has a working binary on first boot.
package app

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/defn/other/m/tenant/library/go/lib/cli"
	"github.com/defn/other/m/tenant/library/go/lib/config"
	"github.com/defn/other/m/tenant/library/go/lib/log"
	"github.com/spf13/cobra"
	"go.uber.org/fx"
	"go.uber.org/fx/fxevent"
	"go.uber.org/zap"
)

type SubCommands struct {
	fx.In
	Commands []cli.Command `group:"subs"`
}

func Run() {
	log.Init(zap.InfoLevel)
	config.Init()

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	var rootCmd *cobra.Command

	app := fx.New(
		fx.WithLogger(func() fxevent.Logger {
			return &fxevent.ZapLogger{Logger: log.Logger().Named("fx").
				WithOptions(zap.IncreaseLevel(zap.WarnLevel))}
		}),
		Modules,
		fx.Invoke(func(root *cobra.Command, subs SubCommands) error {
			rootCmd = root
			if len(subs.Commands) == 0 {
				return fmt.Errorf("no subcommands registered (modules.go missing fx.Module entries?)")
			}
			for _, sub := range subs.Commands {
				root.AddCommand(sub.GetCommand())
			}
			return nil
		}),
	)

	if err := app.Err(); err != nil {
		log.Logger().Fatal("fx construction failed", zap.Error(err))
	}

	if err := app.Start(ctx); err != nil {
		log.Logger().Fatal("start failed", zap.Error(err))
	}

	cmdErr := rootCmd.ExecuteContext(ctx)

	stopCtx, stopCancel := context.WithTimeout(context.Background(), app.StopTimeout())
	defer stopCancel()
	if err := app.Stop(stopCtx); err != nil {
		log.Logger().Fatal("stop failed", zap.Error(err))
	}

	if cmdErr != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", cmdErr)
		os.Exit(1)
	}
}
