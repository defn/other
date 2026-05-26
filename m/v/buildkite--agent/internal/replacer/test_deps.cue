@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"//v/buildkite--agent/internal/redact:redact",
	"@com_github_google_go_cmp//cmp:cmp",
	"@tools_gotest_v3//assert:assert",
]
