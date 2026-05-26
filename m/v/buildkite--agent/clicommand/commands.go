package clicommand

import "github.com/urfave/cli"

var BuildkiteAgentCommands = []cli.Command{
	AgentStartCommand,
	BootstrapCommand,
	{
		Name:  "env",
		Usage: "Interact with the environment of the currently running build",
		Subcommands: []cli.Command{
			EnvDumpCommand,
			EnvGetCommand,
			EnvSetCommand,
			EnvUnsetCommand,
		},
	},
	{
		Name:  "lock",
		Usage: "Lock or unlock resources for the currently running build",
		Subcommands: []cli.Command{
			LockAcquireCommand,
			LockDoCommand,
			LockDoneCommand,
			LockGetCommand,
			LockReleaseCommand,
		},
	},
	{
		Name:  "redactor",
		Usage: "Redact sensitive information from logs",
		Subcommands: []cli.Command{
			RedactorAddCommand,
		},
	},
}
