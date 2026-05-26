@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/hatch",
	"//tenant/library/go/lib/runner",
	"@com_github_coder_acp_go_sdk//:acp-go-sdk",
]
