@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: restamp generator.
//
// Traceability:
//   Go source:      go/lib/gen/restamp/restamp.go
//   Delegates to:   go/lib/stamp/stamp.go (StampBrick)
//   Reads catalogs: catalog.bricks (filtered to stamp_type in
//                   #_restampStampTypes)
//
// Why these files exist: the repo uses `defn stamp <type> <path>` to
// scaffold new bricks (go-lib, go-cmd, go-cmd-cue, go-cmd-parent,
// slack-bot, discord-bot, gmail-bot, matrix-bot, telegram-bot). The
// stamp CLI writes <catalog>/brick-<path-with-dashes>.cue recording
// the brick type so future `mise run gen` runs can re-derive the
// entry from the catalog. restamp is the gen-phase equivalent: it
// iterates every brick whose stamp_type is in the restamp set and
// re-runs StampBrick so edits to the StampBrick template propagate
// across existing bricks automatically.
//
// The brick filename convention (path-with-slashes-replaced-by
// "--") is enforced in stamp.go and mirrored here in CUE. When a
// brick moves on disk, the filename moves with it -- the catalog
// drives this contract, so no hand-maintained list to keep in sync.
//
// Output directory: per AIDR-00071 (kernel/tenant decoupling),
// tenant-pathed bricks land in their owning tenant's catalog/
// (tenant/<owner>/catalog/brick-<slug>.cue) so the kernel substrate
// stays free of tenant-specific brick registrations. Bricks rooted
// elsewhere (kernel/, top-level) keep their kernel/catalog/
// location. Mirrors the rule in stamp.go's brickCatalogDir().
//
// Does NOT claim:
//   - catalog/brick-aidr.cue, catalog/brick-interface--*.cue, and
//     other bricks with no stamp_type (hand-edited).
//   - catalog/brick-app--*.cue (stamp_type: "gen"; claimed by the
//     app generator).
//   - kernel/catalog/gen-infra-bricks.cue (emitted by the infra
//     generator).
//
// See AIDR-00045 (stamp online/offline split), AIDR-00062 (generator
// contracts), AIDR-00071 (kernel/tenant decoupling).

package contracts

import (
	"list"
	"strings"
)

// Bind catalog.bricks from the lattice JSON so the contract can
// iterate every restamp-eligible brick directly. Default stamp_type
// and slug to "" so the comprehension can compare without tripping
// CUE's "cannot reference optional field" rule.
bricks: [string]: {
	path:       string
	slug:       string | *""
	stamp_type: string | *""
	...
}

// Brick stamp_types whose scaffold lives under go/lib/stamp and
// is replayed on every gen. App bricks ("gen") are excluded -- the
// app generator owns those.
_restampStampTypes: [
	"go-lib",
	"go-cmd",
	"go-cmd-cue",
	"go-cmd-parent",
	"skill",
	"slack-bot",
	"discord-bot",
	"gmail-bot",
	"matrix-bot",
	"telegram-bot",
]
_restampStampSet: {for s in _restampStampTypes {(s): true}}

// Tenant-pathed bricks (path begins with tenant/<owner>/) land
// in tenant/<owner>/catalog/.
_restampTenantPaths: [
	for _, b in bricks
	if _restampStampSet[b.stamp_type] != _|_
	let parts = strings.Split(b.path, "/")
	if len(parts) >= 2
	if parts[0] == "tenant" {"tenant/\(parts[1])/catalog/brick-\(b.slug).cue"},
]

// Non-tenant bricks land in kernel/catalog/.
_restampKernelPaths: [
	for _, b in bricks
	if _restampStampSet[b.stamp_type] != _|_
	let parts = strings.Split(b.path, "/")
	if !(len(parts) >= 2 && parts[0] == "tenant") {"kernel/catalog/brick-\(b.slug).cue"},
]

generators: restamp: {
	generator: "restamp"
	source:    "tenant/library/go/lib/gen/restamp"
	reason:    "iterates every brick with a stamp_type in the restamp set and re-invokes StampBrick so changes to the scaffold template propagate across existing bricks on every gen"
	read_from: {
		catalog: ["bricks"]
		paths: ["tenant/library/go/lib/stamp/stamp.go"]
	}
	related_aidr: [45, 62, 71]
	paths: list.Concat([_restampTenantPaths, _restampKernelPaths])
}
