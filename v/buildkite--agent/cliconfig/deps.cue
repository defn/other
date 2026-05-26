@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/internal/osutil",
	"//v/buildkite--agent/logger",
	"@com_github_oleiade_reflections//:reflections",
	"@com_github_urfave_cli//:cli",
]
