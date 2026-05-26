@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@com_github_spf13_viper//:viper",
	"@org_cuelang_go//cue",
	"@org_cuelang_go//cue/cuecontext",
]
