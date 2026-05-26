@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/brickpkg",
	"//tenant/library/go/lib/gen",
	"//tenant/library/go/lib/stamp",
	"@org_cuelang_go//cue",
]
