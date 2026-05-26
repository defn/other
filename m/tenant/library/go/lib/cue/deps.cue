@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@org_cuelang_go//cue",
	"@org_cuelang_go//cue/cuecontext",
	"@org_cuelang_go//cue/load",
	"@org_cuelang_go//encoding/json",
	"@org_cuelang_go//encoding/yaml",
]
