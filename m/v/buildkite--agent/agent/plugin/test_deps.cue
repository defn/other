@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"@com_github_google_go_cmp//cmp:cmp",
]
