@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/logger",
	"@org_golang_x_net//http2",
]
