@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/spec",
	"//tenant/library/go/lib/spec/brickcollision",
	"@org_cuelang_go//cue",
	"@org_cuelang_go//cue/cuecontext",
	"@org_cuelang_go//cue/load",
]
