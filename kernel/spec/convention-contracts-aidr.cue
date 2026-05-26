@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: aidr/ files.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when multiple bricks
// claim conventions concurrently. The original
// convention-contracts.cue holds shared helpers and remaining
// contracts; per-contract shards live in sibling files.
//
// See AIDR-00062 (generator contracts), AIDR-00066 (auto-claim
// taxonomy), AIDR-00083 (sharding policy).

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-aidr": [
	"kernel/spec/convention-contracts-aidr.cue",
]

// ---- aidr/ -- NNNNN-<slug>.md ----------------------------------------

generators: aidr: {
	generator: "aidr"
	source:    "(convention-based; no Go generator)"
	reason:    "AIDRs under aidr/ follow the NNNNN-<slug>.md naming convention; every file matching that pattern is claimed by convention alone. Misnamed files become orphans, which is the intended signal."
	read_from: {
		lattice: ["tree.dirs.m.dirs.aidr"]
	}
	related_aidr: [62, 66]
	paths: [
		for name, f in tree.dirs.m.dirs.aidr.files
		if f.type == "file"
		if name =~ "^[0-9]{5}-[a-z0-9-]+\\.md$" {"aidr/\(name)"},
	]
}
