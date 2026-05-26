@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"@com_github_stretchr_testify//assert:assert",
	"@tools_gotest_v3//assert:assert",
]
