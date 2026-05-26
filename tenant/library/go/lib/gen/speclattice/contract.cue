@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: speclattice generator.
//
// Traceability:
//   Go source:      go/lib/gen/speclattice/speclattice.go
//   Reads:          git ls-files + lattice schema
//
// Why this file exists: speclattice builds the CUE data file that
// underpins spec/lattice.json -- a snapshot of every tracked file's
// path, mode, type, symlink target, and content. The spec_test Go
// code and the spec/lattice-schema.cue CUE tests both consume this
// file. It's also the source this very contracts_vet harness reads.
//
// Runs in Phase C (sequential), after cuetree so its view of the
// repo is consistent with the final manifest.
//
// See AIDR-00061 (lattice schema vet) and AIDR-00062 (contracts).

package contracts

generators: speclattice: {
	generator: "speclattice"
	source:    "tenant/library/go/lib/gen/speclattice"
	reason:    "emits spec/gen-lattice.cue from git ls-files + tracked file contents so CUE tests (lattice_schema_vet, contracts_vet) can query repo state as data"
	read_from: {
		path_globs: ["**"]
		paths: ["kernel/manifest/manifest.cue"]
	}
	related_aidr: [61, 62]
	paths: [
		"var/gen-lattice.cue",
	]
}
