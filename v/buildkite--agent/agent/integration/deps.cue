@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/agent",
	"//v/buildkite--agent/api",
	"//v/buildkite--agent/internal/ptr",
	"//v/buildkite--agent/logger",
	"//v/buildkite--agent/metrics",
	"@com_github_buildkite_bintest_v3//:bintest",
	"@com_github_lestrrat_go_jwx_v2//jwk",
]
