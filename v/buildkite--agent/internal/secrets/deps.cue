@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/api",
	"//v/buildkite--agent/logger",
	"@com_github_buildkite_roko//:roko",
	"@org_golang_x_sync//semaphore",
]
