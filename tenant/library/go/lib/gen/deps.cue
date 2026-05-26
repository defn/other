@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/runner",
	"@org_cuelang_go//cue",
	"@org_cuelang_go//cue/cuecontext",
	"@org_cuelang_go//cue/load",
	"@org_uber_go_zap//:zap",
]
