@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/api/proto/gen",
	"@com_connectrpc_connect//:connect",
]
