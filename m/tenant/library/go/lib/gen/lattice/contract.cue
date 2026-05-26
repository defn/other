@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: lattice generator.
//
// Traceability:
//   Go source:      go/lib/gen/lattice/lattice.go
//   Reads:          in-memory CUE lattice values from ctx
//                   (cuetree + speclattice already populated it)
//
// Why these files exist: lattice serializes the in-memory repo
// lattice (file tree, versions, catalogs) to a sharded layout under
// var/lattice/:
//   - _index.json     (manifest of shards + digests)
//   - _index.sha256   (content digest of merged JSON)
//   - <path>.json     (plain shard, raw < 64 KB)
//   - <path>.json.gz  (gzipped shard, raw >= 64 KB)
//
// The shard set is data-driven: one shard per top-level lattice key
// plus one per top-level repo dir under tree.dirs. Rather than
// enumerating every shard filename, this contract uses Pattern A --
// a CUE comprehension over the lattice tree at var/lattice/
// -- so any shard the generator writes is claimed automatically.
// var/lattice/BUILD.bazel is hand-written and excluded.
//
// Bytes are deterministic functions of the input -- sorted JSON
// keys, zeroed gzip header timestamp + OS byte. See AIDR-00061
// (lattice schema vet) and AIDR-00062 (generator contracts).

package contracts

// _latticeShardDir is the tree node for the shard directory; reading
// it through `tree: _` keeps the comprehension working even before
// the directory is populated for the first time. var/lattice/ is a
// top-level dir (AIDR-00145 D5.1), so the tree path is m/var/lattice.
_latticeShardDir: tree.dirs.m.dirs.var.dirs.lattice

// Every regular file in var/lattice/ except the hand-written
// BUILD.bazel is a generator output.
_latticeShardFiles: [
	for name, f in _latticeShardDir.files
	if f.type == "file"
	if name != "BUILD.bazel" {"var/lattice/\(name)"},
]

generators: lattice: {
	generator: "lattice"
	source:    "tenant/library/go/lib/gen/lattice"
	reason:    "serializes the in-memory lattice (file tree + versions + catalogs) to var/lattice/* shards so CUE tests (lattice_schema_vet, contracts_vet) can query repo state without re-walking files"
	read_from: {
		// In-memory ctx lattice values populated by cuetree +
		// speclattice -- modeled as a dependency on the lattice tree.
		lattice: ["tree"]
	}
	related_aidr: [61, 62]
	paths: _latticeShardFiles
}
