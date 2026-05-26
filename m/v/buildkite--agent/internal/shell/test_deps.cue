@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"//v/buildkite--agent/internal/replacer:replacer",
	"@com_github_buildkite_bintest_v3//:bintest",
	"@com_github_google_go_cmp//cmp:cmp",
	"@tools_gotest_v3//assert:assert",
]

local: true
