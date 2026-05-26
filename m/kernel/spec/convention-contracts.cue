@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-based pattern claims (Pattern C).
//
// Some collections are defined by a file-naming convention rather
// than a Go generator: every file in <dir> that matches the pattern
// is claimed; anything else in <dir> is either hand-listed in
// spec/manual-files.cue or shows up as an orphan. This catches
// misnamed files in a collection (e.g. an AIDR checked in as
// `GRIFT.md` instead of `NNNNN-graft-whitepaper.md`) -- it would
// orphan rather than silently join the allow-list.
//
// Contracts in this file have no Go generator; they declare their
// claims via a CUE comprehension over the lattice tree (the `tree:
// _` placeholder declared in contracts-schema.cue) with a regex on
// each file name.
//
// This is Pattern C of three. See the "How to declare `paths`"
// header in spec/contracts-schema.cue for the full index plus when
// to pick Pattern A (catalog comprehension -- e.g. go/lib/gen/k3d)
// or Pattern B (generator sidecar -- e.g. go/lib/gen/golib). The
// three patterns compose; a single contract can use more than one.
//
// See AIDR-00062 (generator contracts) and AIDR-00066 (auto-claim
// taxonomy).

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts": [
	"kernel/spec/convention-contracts.cue",
]

// Bricks binding shared by the catalog-brick convention below. The
// `stamp_type` default lets the filter compare it without tripping
// "cannot reference optional field". `slug` is the catalog filename
// suffix; every catalog file sets it explicitly (the slug field IS
// the brick's stable identity, decoupled from path).
bricks: [string]: {
	path:       string
	slug:       string | *""
	stamp_type: string | *""
	...
}

// ---- catalog/brick-*.cue -- one per brick, naming by convention ----
//
// Restamp (go/lib/gen/restamp) claims brick files for stamped
// brick types (go-lib, go-cmd, go-cmd-cue, go-cmd-parent, *-bot). The
// remaining hand-written brick files (interfaces, kits, raw
// components, gen-owned components like infra's) follow the
// `brick-<slug>.cue` filename convention -- where slug defaults to
// path stripped of any leading "tenant/<t>/" or "kernel/" prefix --
// but have no stamp_type / stamp_type == "gen" so restamp skips
// them. This contract claims those, filtered to avoid multi-writer
// collisions with restamp.
//
// A misnamed file -- e.g. `brick-AIDR.cue` or `brick-aidr.CUE` --
// won't match the regex and will orphan, which is the intended
// signal.

// Filenames claimed by other generators (restamp + app). catalogbricks
// must exclude these to avoid multi-writer collisions.
_restampOwnedFilenames: {
	for _, b in bricks
	if b.stamp_type != "" if b.stamp_type != "gen" {
		"brick-\(b.slug).cue": true
	}
}

// app generator claims catalog/brick-app--<name>.cue for every app
// in catalog.apps. Mirror that filter here.
_appOwnedFilenames: {
	for k, _ in apps {
		"brick-app--\(k).cue": true
	}
}

// infra generator claims tenant/<owner>/catalog/gen-infra-bricks.cue
// per AIDR-00071 (kernel/tenant decoupling). The filename is
// constant; tenantcatalog must exclude it so the file isn't
// double-claimed.
_infraGenOwnedFilenames: {
	"gen-infra-bricks.cue": true
}

// seed generator may auto-append entries to chart_versions.cue under
// any tenant catalog, per AIDR-00072. The filename is constant; treat
// it as seed-owned so tenantcatalog doesn't double-claim it.
_seedGenOwnedFilenames: {
	"chart_versions.cue": true
}
