@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/cmd/gen",
	"//tenant/library/go/lib/gen",
	"//tenant/library/go/lib/gen/buildsync",
	"//tenant/library/go/lib/gen/lattice",
	"//tenant/library/go/lib/gen/validate",
	"//tenant/library/go/lib/runner",
]
