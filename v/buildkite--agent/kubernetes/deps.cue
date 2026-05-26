@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/logger",
	"//v/buildkite--agent/process",
	"@com_github_buildkite_roko//:roko",
	"@org_golang_x_sys//unix",
]
