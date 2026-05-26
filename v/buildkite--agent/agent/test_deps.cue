@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"//v/buildkite--agent/api/proto/gen/agentedgev1connect:agentedgev1connect",
	"@com_github_google_go_cmp//cmp:cmp",
	"@com_github_google_uuid//:uuid",
	"@com_github_stretchr_testify//assert:assert",
	"@com_github_stretchr_testify//require:require",
]
