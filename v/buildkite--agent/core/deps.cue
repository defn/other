@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/api",
	"//v/buildkite--agent/logger",
	"//v/buildkite--agent/version",
	"@com_github_buildkite_roko//:roko",
	"@com_github_denisbrodbeck_machineid//:machineid",
]
