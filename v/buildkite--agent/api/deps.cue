@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/api/proto/gen",
	"//v/buildkite--agent/api/proto/gen/agentedgev1connect",
	"//v/buildkite--agent/internal/agenthttp",
	"//v/buildkite--agent/logger",
	"@com_connectrpc_connect//:connect",
	"@com_github_buildkite_go_pipeline//:go-pipeline",
	"@com_github_buildkite_roko//:roko",
	"@com_github_google_go_querystring//query",
	"@com_github_klauspost_compress//gzip",
	"@com_github_pborman_uuid//:uuid",
]
