@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/cmd/gen",
	"//tenant/library/go/lib/gen",
	"//tenant/library/go/lib/gen/buildsync",
	"//tenant/library/go/lib/gen/lattice",
	"//tenant/library/go/lib/gen/validate",
	"//tenant/library/go/lib/runner",
	"//tenant/library/go/lib/spec",
	"//tenant/library/go/lib/spec/brickreads",
	"@org_cuelang_go//cue",
	"@org_cuelang_go//cue/cuecontext",
	"@org_cuelang_go//cue/load",
	"@org_cuelang_go//encoding/json",
]
