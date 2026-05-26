@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"@org_cuelang_go//cue",
	"@org_cuelang_go//cue/cuecontext",
]

test_data: []
