@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: tenantcatalog.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-tenantcatalog": [
	"kernel/spec/convention-contracts-tenantcatalog.cue",
]

// ---- tenant/<t>/catalog/*.cue -- per-tenant instance data ----------
//
// Each tenant owns a catalog/ dir holding `package catalog` files
// that are unioned with kernel/catalog at load time. Files are
// hand-authored (or stamped by future tenant-aware stamps); shape is
// validated by CUE schema in kernel/schema, not by manifest filename.

generators: tenantcatalog: {
	generator: "tenantcatalog"
	source:    "(convention-based; no Go generator)"
	reason:    "tenant/<t>/catalog/*.cue is per-tenant instance data unioned into the catalog at load time. Filenames also claimed by restamp or app are excluded so a tenant-pathed generator-emitted brick (AIDR-00071) is not double-claimed."
	read_from: {
		lattice: ["tree.dirs.m.dirs.tenant"]
	}
	related_aidr: [62, 66, 71]
	paths: [
		for tName, t in tree.dirs.m.dirs.tenant.dirs
		if t.dirs != _|_
		if t.dirs.catalog != _|_
		for name, f in t.dirs.catalog.files
		if f.type == "file"
		if name =~ "\\.cue$"
		if _restampOwnedFilenames[name] == _|_
		if _appOwnedFilenames[name] == _|_
		if _infraGenOwnedFilenames[name] == _|_
		if _seedGenOwnedFilenames[name] == _|_ {"tenant/\(tName)/catalog/\(name)"},
	]
}
