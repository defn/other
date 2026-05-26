@experiment(aliasv2,explicitopen,shortcircuit,try)

// AIDR-00099: catalog of `defn check` leaves. Each entry documents the
// contract for one check subcommand. No new Midas kind today --
// stamping uses gocmdparent (cmd/check/) + gocmd (cmd/check/<name>/).
//
// AIDR-00100 widened #Check.input from a fixed string to a closed
// disjunction when contracts + latticeschema landed alongside
// brickcollision.
//
// When a third+ checker lands, the entries here become the
// requirements list for a future `check` Midas (follow-up AIDR).
package catalog

#Check: {
	// CLI leaf name, e.g. "brickcollision". Must match the gocmd
	// brick directory under cmd/check/.
	name: string

	// One-line summary surfaced by `defn check <name> --help`.
	short: string

	// Owning AIDR (author of the check's semantics).
	aidr: string

	// Input shape: how the check obtains its data. Closed disjunction;
	// extend with new entries as new check shapes land. Today:
	//   "cue-brick-io"           -- evaluates brick_io + bricks from
	//                               the contracts package + lattice
	//   "cue-vet-contracts"      -- vets contracts package against the
	//                               lattice for orphans, missingClaims,
	//                               manualClaimed, unannouncedShared
	//   "cue-vet-lattice-schema" -- vets the lattice JSON against
	//                               kernel/spec/lattice-schema.cue
	//   "cross-tenant-lit"       -- AIDR-00102 / SPEC-00352:
	//                               filesystem walk over leaf tenant
	//                               trees + cue eval for the
	//                               brick_io.writes generator-output
	//                               skip set
	input: "cue-brick-io" | "cue-vet-contracts" | "cue-vet-lattice-schema" | "cross-tenant-lit"

	// Exit-code contract:
	//   0 = clean (no violations)
	//   1 = violations found (one line per violation on stdout)
	//   2 = usage / IO error
	exit_codes: {
		clean:      0
		violations: 1
		error:      2
	}
}

checks: [string]: #Check

checks: {
	brickcollision: {
		name:  "brickcollision"
		short: "AIDR-00098: pairwise-write-intersection check for parallel dispatch safety"
		aidr:  "AIDR-00098"
		input: "cue-brick-io"
		exit_codes: clean:      0
		exit_codes: violations: 1
		exit_codes: error:      2
	}
	contracts: {
		name:  "contracts"
		short: "AIDR-00062: generator-contracts vet (orphans, missingClaims, manualClaimed, unannouncedShared)"
		aidr:  "AIDR-00062"
		input: "cue-vet-contracts"
		exit_codes: clean:      0
		exit_codes: violations: 1
		exit_codes: error:      2
	}
	latticeschema: {
		name:  "latticeschema"
		short: "AIDR-00061: lattice JSON conforms to kernel/spec/lattice-schema.cue"
		aidr:  "AIDR-00061"
		input: "cue-vet-lattice-schema"
		exit_codes: clean:      0
		exit_codes: violations: 1
		exit_codes: error:      2
	}
	crosstenantlit: {
		name:  "crosstenantlit"
		short: "AIDR-00102: cross-tenant literal vet (SPEC-00352) -- forbid leaf tenants from naming each other in active code"
		aidr:  "AIDR-00102"
		input: "cross-tenant-lit"
		exit_codes: clean:      0
		exit_codes: violations: 1
		exit_codes: error:      2
	}
}
