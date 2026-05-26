@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/clicommand",
	"//v/buildkite--agent/env",
	"//v/buildkite--agent/internal/experiments",
	"//v/buildkite--agent/internal/job",
	"//v/buildkite--agent/internal/shell",
	"@com_github_buildkite_bintest_v3//:bintest",
	"@tools_gotest_v3//assert",
]
