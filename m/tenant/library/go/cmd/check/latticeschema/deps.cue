@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/spec",
	"@org_cuelang_go//cue",
	"@org_cuelang_go//cue/cuecontext",
	"@org_cuelang_go//cue/errors",
	"@org_cuelang_go//cue/load",
	"@org_cuelang_go//encoding/json",
]
