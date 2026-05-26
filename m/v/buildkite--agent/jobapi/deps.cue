@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/env",
	"//v/buildkite--agent/internal/replacer",
	"//v/buildkite--agent/internal/shell",
	"//v/buildkite--agent/internal/socket",
	"@com_github_go_chi_chi_v5//:chi",
	"@com_github_go_chi_chi_v5//middleware",
]
