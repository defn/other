@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/internal/socket",
	"//v/buildkite--agent/logger",
	"@com_github_go_chi_chi_v5//:chi",
	"@com_github_go_chi_chi_v5//middleware",
]
