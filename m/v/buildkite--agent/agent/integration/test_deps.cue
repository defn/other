@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"//v/buildkite--agent/clicommand:clicommand",
	"//v/buildkite--agent/version:version",
	"@com_github_buildkite_go_pipeline//:go-pipeline",
	"@com_github_buildkite_go_pipeline//signature:signature",
	"@com_github_urfave_cli//:cli",
	"@tools_gotest_v3//assert:assert",
]

local: true
