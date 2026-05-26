@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/clicommand",
	"//v/buildkite--agent/version",
	"@com_github_urfave_cli//:cli",
]
