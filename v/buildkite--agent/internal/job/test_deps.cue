@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"//v/buildkite--agent/internal/job/githttptest:githttptest",
	"//v/buildkite--agent/internal/race:race",
	"@com_github_buildkite_bintest_v3//:bintest",
	"@com_github_gliderlabs_ssh//:ssh",
	"@com_github_google_go_cmp//cmp:cmp",
	"@com_github_stretchr_testify//assert:assert",
	"@com_github_stretchr_testify//require:require",
]

local: true
