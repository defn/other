package hook_test

import (
	"os"
	"strings"
	"testing"

	"github.com/defn/other/m/v/buildkite--agent/clicommand"
	"github.com/defn/other/m/v/buildkite--agent/version"
	"github.com/urfave/cli"
)

func TestMain(m *testing.M) {
	if len(os.Args) <= 1 || strings.HasPrefix(os.Args[1], "-test.") {
		os.Exit(m.Run())
	}

	app := cli.NewApp()
	app.Name = "buildkite-agent"
	app.Version = version.Version()
	app.Commands = []cli.Command{
		{
			Name: "env",
			Subcommands: []cli.Command{
				clicommand.EnvDumpCommand,
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		os.Exit(clicommand.PrintMessageAndReturnExitCode(err))
	}
}
