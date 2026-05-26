@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@com_github_spf13_cobra//:cobra",
	"@org_uber_go_fx//:fx",
	"@org_uber_go_zap//:zap",
]
