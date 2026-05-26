@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: formatters.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083.
// Per AIDR-00083's leaves-into-branches model,
// kernel/catalog/formatters.cue is sharded per-formatter
// (formatters-<name>.cue) so adding a formatter is a single-file
// write that doesn't collide with sibling formatter additions.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-formatters": [
	"kernel/spec/convention-contracts-formatters.cue",
]

// ---- kernel/catalog/formatters-*.cue -- one per formatter ----------

generators: formatterscatalog: {
	generator: "formatterscatalog"
	source:    "(convention-based; no Go generator)"
	reason:    "formatter instance metadata is sharded per-formatter into kernel/catalog/formatters-<name>.cue (AIDR-00083). The base formatters.cue holds schema only."
	read_from: {
		lattice: ["tree.dirs.m.dirs.kernel.dirs.catalog"]
	}
	related_aidr: [62, 66, 83]
	paths: [
		for name, f in tree.dirs.m.dirs.kernel.dirs.catalog.files
		if f.type == "file"
		if name =~ "^formatters-[a-z][a-z0-9-]*\\.cue$" {"kernel/catalog/\(name)"},
	]
}
