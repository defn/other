@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contracts schema: CUE-native generator output contracts.
//
// Every Go generator under go/lib/gen/<name>/ declares a
// contract.cue at go/lib/gen/<name>/contract.cue describing:
//   - which files it writes
//   - which generator it is
//   - why (human-readable reason)
//   - where its Go source lives
//
// All contracts share `package contracts`. The vet runner
// (//spec:contracts_vet) unifies them with this schema and with
// spec/lattice.json, then asserts:
//
//   1. Every claimed path exists in the lattice.
//   2. Every path under the scoped subtree is claimed or in the
//      manual allow-list (spec/manual-files.cue); anything else is
//      an orphan and the vet fails.
//   3. Every multi-writer path (claimed by >1 generator) appears in
//      spec/known-shared.cue with a reason and a consolidate plan.
//
// See AIDR-00062 for rationale, and the header of
// spec/lattice-schema.cue for related CUE patterns.
//
// ---- How to declare `paths` (three patterns; pick one) -------------
//
// A contract can fill its `paths:` list three ways. They compose:
// a single contract can use more than one. AIDR-00066 documents the
// taxonomy and tradeoffs in depth; this is the index.
//
//  Pattern A -- catalog comprehension.
//    For generators whose brick roster lives in the catalog and
//    whose per-brick file set is fixed. Iterate the catalog in CUE,
//    cross with a literal filename list. No sidecar, no hand-maintained
//    roster.
//      Exemplars: go/lib/gen/k3d/contract.cue
//                 go/lib/gen/fmt/contract.cue
//                 go/lib/gen/slackbot/contract.cue
//                 go/lib/gen/k8s/contract.cue
//
//  Pattern B -- generator-emitted inputs block (inline in contract.cue).
//    For generators whose per-brick file set VARIES (arbitrary .go
//    sources, versioned chart tarballs, tofu lock files). The
//    generator walks each brick at stamp time and rewrites a
//    marker-delimited region inside its own contract.cue carrying
//    a hidden field (`_<gen>_inputs`); the hand-written part of the
//    contract concatenates that field via list.Concat. Pattern A
//    still supplies the brick roster; Pattern B only covers the
//    variable files.
//
//    The generator-managed region is bounded by:
//      // === BEGIN GENERATED: _<gen>_inputs ===
//      ...
//      // === END GENERATED: _<gen>_inputs ===
//
//      Exemplars: go/lib/gen/golib/contract.cue
//                 go/lib/gen/app/contract.cue
//                 go/lib/gen/infra/contract.cue
//    Helpers:    go/lib/gen/golib.CollectBrickInputs,
//                go/lib/gen/golib.WriteInputsBlock.
//
//    History: pre-AIDR-00093 the data lived in a sibling inputs.cue
//    file; AIDR-00093 folded it into contract.cue to halve the
//    per-generator file count.
//
//  Pattern C -- convention-based regex claim (no Go generator).
//    For collections defined by a naming convention where the regex
//    IS the spec. Misnamed files orphan, which is the intended
//    signal. Lives in spec/convention-contracts.cue; source field
//    uses the "(convention-based...)" literal.
//      Exemplars: aidr/, .mise/tasks/, schema/, doc/, module/,
//                 catalog/brick-*.cue (all in spec/convention-contracts.cue).
//
// When extending: a generator that meets "catalog-driven roster AND
// fixed file set" should use Pattern A and ship no sidecar (see e22c6bf7
// where fmt/image/k8s retired their sidecars). A generator that needs
// Pattern B implicitly also uses Pattern A for the roster.
//
// ---- Gotchas -------------------------------------------------------
//
// 1. Optional-field references (`files?:`) cannot be read directly in
//    CUE expressions -- "cannot reference optional field". Walk the
//    concrete lattice data via `tree: _` placeholder + guards like
//    `if d.dirs != _|_` to cope with missing subdirs.
//
// 2. List `+` is deprecated; use `list.Concat([a, b, c])` for
//    flattening. CUE 0.11+ requirement.
//
// 3. Day one scopes the closed-universe check to the go/cmd/ subtree
//    only. Other subtrees land incrementally. Until every subtree has
//    contracts + manual entries, orphan detection for the whole repo
//    would false-positive on everything, so `scopedPaths` is
//    hand-picked.
//
// -------------------------------------------------------------------

package contracts

import (
	"list"
	"strings"
)

// ---- Generator contract shape -------------------------------------

// #Generator describes one generator's output surface.
//
// Fields:
//   generator    -- short ID, matches the directory name under
//                   go/lib/gen/<name>/
//   source       -- workspace-relative path to the generator source
//                   directory. Vet asserts this matches the contract
//                   file's location.
//   reason       -- one-sentence rationale: what question these files
//                   answer. Must be non-empty (=~".+").
//   paths        -- exact output file paths (per-file granularity).
//                   Comprehensions preferred; literal lists tolerated
//                   as a greppable escape hatch (per AIDR-00093).
//   read_from    -- structured declaration of inputs the generator
//                   reads. Each sub-field is optional (absent =
//                   doesn't read that kind). Drives the planner's
//                   load/analyze phase per AIDR-00086.
//   related_aidr -- optional AIDR numbers explaining the design.
//
// See AIDR-00093 for the strict schema design and migration spec.
#Generator: close({
	generator: =~"^[a-z][a-z0-9]*$"
	// `source` normally points at tenant/library/go/lib/gen/<name>/.
	// Pattern-based contracts (those that claim by filename convention
	// with no Go generator) escape this via the "(convention...)"
	// literal.
	source: =~"^tenant/library/go/lib/gen/[a-z][a-z0-9]*$" | =~"^\\(convention"
	reason: =~".+"
	paths: [...string]

	// Structured input declaration. Each sub-field maps to a distinct
	// change-detection mechanism the planner uses to decide when a
	// generator must re-run:
	//   paths      -- mtime/digest on a concrete path
	//   path_globs -- filesystem walk + glob match
	//   catalog    -- CUE re-eval against catalog package
	//   schema     -- CUE re-eval against schema package
	//   lattice    -- lattice payload regeneration
	read_from: close({
		paths?: [...string]
		path_globs?: [...string]
		catalog?: [...string]
		schema?: [...string]
		lattice?: [...string]
	})

	related_aidr?: [...int]
})

// Populated by per-generator contract.cue files colocated with their
// Go source.
generators: [string]: #Generator

// ---- Known-shared (multi-writer) allow-list -----------------------

// #KnownShared entries document paths that multiple generators
// intentionally claim. Every multi-writer that isn't listed here
// fails the vet.
//
// consolidate: describes the plan to collapse writers, or "keep as-is"
// with justification. This field is the maintenance backlog for
// "should we consolidate?" work.
#KnownShared: {
	path: =~".+"
	writers: [...string]
	reason:      =~".+"
	consolidate: =~".+"
}

knownShared: [string]: #KnownShared

// ---- Manual allow-list --------------------------------------------

// Files that are intentionally hand-written. Seeded from git ls-files
// minus anything tagged `generated`. Any file outside claimedPaths
// and outside manualFiles is an orphan.
//
// Sharded across multiple files (manual-files-<section>.cue) per
// AIDR-00083 to allow parallel agents to add entries without
// colliding on a single file. Each shard contributes to
// _manualFileShards under a unique key; manualFiles is computed as
// the concatenation. CUE struct unification means shards can be
// added or split without touching this schema.
_manualFileShards: [string]: [...string]
manualFiles: list.Concat([for _, s in _manualFileShards {s}])

// ---- Lattice hook -------------------------------------------------

// The lattice JSON is passed positionally to cue vet. `tree: _`
// gives the walker a handle without imposing a schema on the data
// (CUE forbids referencing optional fields, so we walk concrete
// values instead of a typed map).
tree: _

// Bind catalog.bricks from the lattice JSON so brick_io (below) can
// project per-brick fingerprints. Same `name: _` placeholder pattern
// fmt's contract uses for `formatters: _`.
bricks: _

// ---- Scoped paths --------------------------------------------------
//
// scopedPaths enumerates every file under the subtrees currently
// covered by contracts + manual-files. Expansion to a new subtree
// means adding a walker below AND concatenating its output into
// scopedPaths AND seeding spec/manual-files.cue with any hand-written
// files there AND adding a contract for the generators that write
// the rest.
//
// Walkers are inlined per subtree rather than abstracted into a
// function, because CUE's lack of first-class functions over struct
// values makes the generic-walker path awkward. Inlining stays
// obvious and the list doesn't grow quickly -- few subtrees per PR.

// ---- go/cmd/ (from AIDR-00061 era) --------------------------------

_cmdDir: tree.dirs.m.dirs.go.dirs.cmd

_cmdD2: [
	for dName, d in _cmdDir.dirs
	if d.files != _|_
	for name, f in d.files
	if f.type == "file" {"go/cmd/\(dName)/\(name)"},
]

_cmdD3: [
	for dName, d in _cmdDir.dirs
	if d.dirs != _|_
	for sName, sub in d.dirs
	if sub.files != _|_
	for name, f in sub.files
	if f.type == "file" {"go/cmd/\(dName)/\(sName)/\(name)"},
]

// ---- repo root files (phase 2) ------------------------------------
//
// The repo root has ~20 tracked files, mostly hand-written
// (.bazelrc, .gitignore, go.mod, etc.) plus three files patched
// by generators: .bazelversion, MODULE.bazel, mise.toml.

_mDir: tree.dirs.m

_repoRoot: [
	for name, f in _mDir.files
	if f.type == "file" {(name)},
]

// ---- gen-versions/ (phase 2) --------------------------------------
//
// versionsbzl writes one <tool>.bzl per schema.versions entry
// (~113 files); gen-versions/BUILD.bazel is hand-written.

_gvDir: tree.dirs.m.dirs.kernel.dirs."gen-versions"

_genVersions: [
	for name, f in _gvDir.files
	if f.type == "file" {"kernel/gen-versions/\(name)"},
]

// ---- root/.config/mise/ (phase 2) ---------------------------------
//
// misetoml writes config.toml here. The `.config` path segment
// requires CUE string-key quoting.

_miseDir: tree.dirs.m.dirs.root.dirs.".config".dirs.mise

_rootConfigMise: [
	for name, f in _miseDir.files
	if f.type == "file" {"root/.config/mise/\(name)"},
]

// ---- oci/ (phase 6) -------------------------------------------------
//
// 2 OCI image bricks at depth 2.

_ociDir: tree.dirs.m.dirs.kernel.dirs.oci

_ociD1: [
	for name, f in _ociDir.files
	if f.type == "file" {"kernel/oci/\(name)"},
]

_ociD2: [
	for sName, sub in _ociDir.dirs
	if sub.files != _|_
	for name, f in sub.files
	if f.type == "file" {"kernel/oci/\(sName)/\(name)"},
]

// ---- image/ (phase 6) -----------------------------------------------
//
// image/docker/<brick>/ (generated BUILD.bazel + mise.toml + hand-
// written Dockerfile) and image/packer/<brick>/ (entirely hand-
// written). Depths 2-3 under image/.

_imageDir: tree.dirs.m.dirs.kernel.dirs.image

_imageD1: [
	for name, f in _imageDir.files
	if f.type == "file" {"kernel/image/\(name)"},
]

_imageD2: [
	for sName, sub in _imageDir.dirs
	if sub.files != _|_
	for name, f in sub.files
	if f.type == "file" {"kernel/image/\(sName)/\(name)"},
]

_imageD3: [
	for sName, sub in _imageDir.dirs
	if sub.dirs != _|_
	for subName, subsub in sub.dirs
	if subsub.files != _|_
	for name, f in subsub.files
	if f.type == "file" {"kernel/image/\(sName)/\(subName)/\(name)"},
]

// ---- kernel/fmt/ (phase 5) ------------------------------------------
//
// 15 formatter bricks at depth 2 (BUILD.bazel + formatter.cue each).
// kernel/fmt/.mise/tasks/ has hand-written Clojure fmt runners at depth 3.

_fmtDir: tree.dirs.m.dirs.kernel.dirs.fmt

_fmtD1: [
	for name, f in _fmtDir.files
	if f.type == "file" {"kernel/fmt/\(name)"},
]

_fmtD2: [
	for sName, sub in _fmtDir.dirs
	if sub.files != _|_
	for name, f in sub.files
	if f.type == "file" {"kernel/fmt/\(sName)/\(name)"},
]

_fmtD3: [
	for sName, sub in _fmtDir.dirs
	if sub.dirs != _|_
	for subName, subsub in sub.dirs
	if subsub.files != _|_
	for name, f in subsub.files
	if f.type == "file" {"kernel/fmt/\(sName)/\(subName)/\(name)"},
]

// ---- composed --------------------------------------------------------

// Full closed-universe: every file in the lattice must be claimed
// by a generator contract or listed in manual-files.cue.
// Set scopedPaths = allPaths to enable repo-wide orphan detection.
// The individual per-subtree walkers above are retained as
// documentation of how scope was expanded incrementally; the
// composed form is simply overridden here.
scopedPaths: allPaths

// ---- Full-lattice paths (for missingClaims check) ------------------
//
// missingClaims needs to verify that every claimed path refers to a
// real file, even when the file lives outside the currently-scoped
// subtrees. Without this split, a generator like buildsync that
// writes across multiple subtrees (k3d/, hello/, cue.mod/,
// root/.aws/, etc.) couldn't land its full contract until every
// target subtree is scoped.
//
// The walker below collects every file in tree.dirs.m at depths 1-4.
// Most generators don't write deeper than that; when one does, add
// a depth-5 branch here. This is still a bounded, explicit walk --
// recursive descent over closed structs is awkward in CUE, and the
// explicit form is readable.

_mFiles: tree.dirs.m

_allD1: [
	for name, f in _mFiles.files
	if f.type == "file" {(name)},
]

_allD2: [
	for aName, a in _mFiles.dirs
	if a.files != _|_
	for name, f in a.files
	if f.type == "file" {"\(aName)/\(name)"},
]

_allD3: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.files != _|_
	for name, f in b.files
	if f.type == "file" {"\(aName)/\(bName)/\(name)"},
]

_allD4: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.files != _|_
	for name, f in c.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(name)"},
]

_allD5: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.dirs != _|_
	for dName, d in c.dirs
	if d.files != _|_
	for name, f in d.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(dName)/\(name)"},
]

_allD6: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.dirs != _|_
	for dName, d in c.dirs
	if d.dirs != _|_
	for eName, e in d.dirs
	if e.files != _|_
	for name, f in e.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(dName)/\(eName)/\(name)"},
]

_allD7: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.dirs != _|_
	for dName, d in c.dirs
	if d.dirs != _|_
	for eName, e in d.dirs
	if e.dirs != _|_
	for gName, g in e.dirs
	if g.files != _|_
	for name, f in g.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(dName)/\(eName)/\(gName)/\(name)"},
]

_allD8: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.dirs != _|_
	for dName, d in c.dirs
	if d.dirs != _|_
	for eName, e in d.dirs
	if e.dirs != _|_
	for gName, g in e.dirs
	if g.dirs != _|_
	for hName, h in g.dirs
	if h.files != _|_
	for name, f in h.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(dName)/\(eName)/\(gName)/\(hName)/\(name)"},
]

_allD9: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.dirs != _|_
	for dName, d in c.dirs
	if d.dirs != _|_
	for eName, e in d.dirs
	if e.dirs != _|_
	for gName, g in e.dirs
	if g.dirs != _|_
	for hName, h in g.dirs
	if h.dirs != _|_
	for iName, i in h.dirs
	if i.files != _|_
	for name, f in i.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(dName)/\(eName)/\(gName)/\(hName)/\(iName)/\(name)"},
]

_allD10: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.dirs != _|_
	for dName, d in c.dirs
	if d.dirs != _|_
	for eName, e in d.dirs
	if e.dirs != _|_
	for gName, g in e.dirs
	if g.dirs != _|_
	for hName, h in g.dirs
	if h.dirs != _|_
	for iName, i in h.dirs
	if i.dirs != _|_
	for jName, j in i.dirs
	if j.files != _|_
	for name, f in j.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(dName)/\(eName)/\(gName)/\(hName)/\(iName)/\(jName)/\(name)"},
]

_allD11: [
	for aName, a in _mFiles.dirs
	if a.dirs != _|_
	for bName, b in a.dirs
	if b.dirs != _|_
	for cName, c in b.dirs
	if c.dirs != _|_
	for dName, d in c.dirs
	if d.dirs != _|_
	for eName, e in d.dirs
	if e.dirs != _|_
	for gName, g in e.dirs
	if g.dirs != _|_
	for hName, h in g.dirs
	if h.dirs != _|_
	for iName, i in h.dirs
	if i.dirs != _|_
	for jName, j in i.dirs
	if j.dirs != _|_
	for kName, k in j.dirs
	if k.files != _|_
	for name, f in k.files
	if f.type == "file" {"\(aName)/\(bName)/\(cName)/\(dName)/\(eName)/\(gName)/\(hName)/\(iName)/\(jName)/\(kName)/\(name)"},
]

// Everything under m/ at depths 1-11. Sufficient for the deepest
// claimed output today (v/galleybytes--terraform-operator/pkg/client/
// clientset/versioned/typed/tf/v1beta1/fake/BUILD.bazel at depth 11).
// When a generator writes deeper than 11 dirs below m/, add a _allD12
// branch here. The copy-paste walker pattern is ugly but CUE's lack
// of recursion over struct positions makes the alternative (a truly
// recursive walker) awkward.
allPaths: list.Concat([_allD1, _allD2, _allD3, _allD4, _allD5, _allD6, _allD7, _allD8, _allD9, _allD10, _allD11])

// ---- Derived: flattened claims -----------------------------------

// claimedPaths is the union of every generator's paths field.
claimedPaths: [
	for _, g in generators
	for p in g.paths {p},
]

// claimsByPath maps path -> [generator...] for multi-writer detection.
// Re-iterates generators per claimed path (O(n*m) but n and m are
// small in practice).
claimsByPath: {
	for p in claimedPaths {
		(p): [
			for gName, g in generators
			if list.Contains(g.paths, p) {gName},
		]
	}
}

// ---- Set-based indexes for O(1) lookup -----------------------------
//
// list.Contains is O(n) per call. With ~3300 allPaths, ~1400
// claimedPaths, ~1800 manualFiles, the naive orphan check does
// 3300 * (1400 + 1800) = ~10M comparisons. Converting to map
// indexes makes each lookup O(1) via CUE struct key resolution.

_allPathsSet: {for p in allPaths {(p): true}}
_claimedSet: {for p in claimedPaths {(p): true}}
_manualSet: {for p in manualFiles {(p): true}}
_sharedSet: {for _, k in knownShared {(k.path): true}}

// ---- Vet assertions -----------------------------------------------
//
// Each rule has TWO declarations: the public field with the
// comprehension and the assertion (`<field>: []`), AND a hidden
// `_<field>Out` mirror that holds the same computed list without
// the assertion. The hidden mirror lets `defn check contracts`
// extract the actual offending paths when an assertion fails --
// CUE's stock "incompatible list lengths" error doesn't include
// the contents, so without the mirror the operator gets only a
// schema:line:col with no path. With the mirror, the diagnostic
// names every path.

// 1. Every claimed path must exist in the lattice. Checked against
//    allPaths (full m/ walk) rather than scopedPaths, so a generator
//    can claim files outside the currently-scoped subtrees without
//    requiring those subtrees to land first.
_missingClaimsOut: [
	for p in claimedPaths
	if _allPathsSet[p] == _|_ {p},
]
missingClaims: _missingClaimsOut
missingClaims: []

// 2. Every file must be claimed or in the manual allow-list.
_orphansOut: [
	for p in scopedPaths
	if _claimedSet[p] == _|_
	if _manualSet[p] == _|_ {p},
]
orphans: _orphansOut
orphans: []

// 3. Every multi-writer path must appear in knownShared.
_unannouncedSharedOut: [
	for p, writers in claimsByPath
	if len(writers) > 1
	if _sharedSet[p] == _|_ {p},
]
unannouncedShared: _unannouncedSharedOut
unannouncedShared: []

// 3b. manualFiles and claimedPaths must be disjoint. A file either
//     has a generator claim or is hand-written -- never both.
_manualClaimedOut: [
	for p in manualFiles
	if _claimedSet[p] != _|_ {p},
]
manualClaimed: _manualClaimedOut
manualClaimed: []

// 4. source field of every Go-backed generator points at the directory
//    whose name matches the generator key. Convention: contract.cue
//    lives next to its generator's Go source. Convention-based
//    generators (source starts with "(convention") are exempt because
//    they have no Go source directory.
_sourceMismatch: [
	for gName, g in generators
	if !(g.source =~ "^\\(convention")
	if g.source != "tenant/library/go/lib/gen/\(gName)" {gName},
]
_sourceMismatch: []

// 5. Every contract.cue file under tenant/library/go/lib/gen/<name>/
//    must be loaded into this contracts package. If a generator's
//    contract.cue exists on disk but no `generators: <name>` entry
//    materializes, the contracts_vet test args are missing it -- a
//    coverage gap that silently lets that generator's contract drift
//    out of date.
//
//    See: this catch found awsconfig missing from contracts_vet
//    (commit 84721715 + follow-up). The strict schema's test surface
//    is only as good as its coverage of the contract files on disk.
//
//    Path retargeted on 2026-05-18 (AIDR-00144 review fix): generators
//    moved from go/internal/gen -> go/lib/gen (commit 20147868)
//    -> tenant/library/go/lib/gen (commit a6bb7d51 / Stage 3.5a).
//    The pre-fix path (tree.dirs.m.dirs.go.dirs.internal.dirs.gen.dirs)
//    silently resolved to _|_, making this assertion a tautology.
_genDirs: tree.dirs.m.dirs.tenant.dirs.library.dirs.go.dirs.lib.dirs.gen.dirs
_expectedGenerators: {
	for name, dir in _genDirs
	if dir.files != _|_
	if dir.files["contract.cue"] != _|_ {(name): true}
}
_unloadedGenerators: [
	for name, _ in _expectedGenerators
	if generators[name] == _|_ {name},
]
_unloadedGenerators: []

// 6. Every generator's `generator` field equals its struct key.
//    Catches typos like `generators: foo: { generator: "fop" }`.
_generatorKeyMismatch: [
	for gName, g in generators
	if g.generator != gName {gName},
]
_generatorKeyMismatch: []

// 7. Every generator must declare at least one concrete input entry
//    in read_from. An empty read_from (or one with only empty lists)
//    means the planner has no dependency information for this
//    generator, which breaks parallel-subagent dispatch correctness
//    per AIDR-00086.
//
//    This is a forward-guard against drift; today all 29 contracts
//    populate read_from with at least one sub-field. See AIDR-00095.
//
//    Per-sub-field has_entry booleans use the "default false +
//    conditional override true" pattern because read_from sub-fields
//    are optional (paths?:, path_globs?:, ...) and referencing an
//    absent optional field yields _|_; the guard chains
//    `if X != _|_ if len(X) > 0` flip the boolean only when the
//    sub-field is both present AND non-empty.
_readFromHasEntry: {
	for gName, g in generators {
		(gName): {
			has_paths: bool | *false
			if g.read_from.paths != _|_ if len(g.read_from.paths) > 0 {
				has_paths: true
			}
			has_globs: bool | *false
			if g.read_from.path_globs != _|_ if len(g.read_from.path_globs) > 0 {
				has_globs: true
			}
			has_catalog: bool | *false
			if g.read_from.catalog != _|_ if len(g.read_from.catalog) > 0 {
				has_catalog: true
			}
			has_schema: bool | *false
			if g.read_from.schema != _|_ if len(g.read_from.schema) > 0 {
				has_schema: true
			}
			has_lattice: bool | *false
			if g.read_from.lattice != _|_ if len(g.read_from.lattice) > 0 {
				has_lattice: true
			}
		}
	}
}

// Struct-shape (rather than list-shape) so a violation surfaces the
// offending generator key in the error message (e.g.
// `_emptyReadFrom.fmt: field not allowed`) instead of the bare
// "incompatible list lengths" text. Same agent-debuggability shape
// the AIDR-00095 spec called for.
_emptyReadFrom: {
	for gName, h in _readFromHasEntry
	if !h.has_paths && !h.has_globs && !h.has_catalog && !h.has_schema && !h.has_lattice {
		(gName): "must declare at least one read_from sub-field with at least one entry"
	}
}
_emptyReadFrom: close({})

// ---- Per-brick read/write fingerprint (AIDR-00096) -----------------
//
// brick_io exposes the effective reads/writes fingerprint of every
// brick by intersecting each generator's claimed paths/read_from with
// the brick's path prefix. This avoids a stamp_type -> generator
// registry (the AIDR's original design) because reality is messier:
// 85 bricks share `stamp_type: "gen"` (formatters, apps, k3d, etc.),
// and a registry would still need a per-stamp_type discriminator
// (`implements`, path prefix, etc.) to be useful. Path-prefix
// intersection IS the discriminator, so the registry layer is
// vestigial.
//
// Derivation per brick b:
//   derived_writes = paths from any generator g where p starts with b.path+"/"
//   derived_reads  = read_from.paths and read_from.path_globs from any
//                    generator g where p starts with b.path+"/"
//
// The aggregation unions derived sets with declared reads/writes if
// the brick set them inline. For hand-edited bricks (no generator
// writes under their prefix), derivation yields empty; populating
// declarations is a follow-up to AIDR-00096 and is NOT enforced by
// vet in this pass -- vet integration is the next AIDR.

_brickPrefixedClaims: {
	for slug, b in bricks {
		(slug): [
			for _, g in generators
			for p in g.paths
			if strings.HasPrefix(p, b.path+"/") {p},
		]
	}
}

// AIDR-00097: manualFiles-aware brick_io derivation. Hand-edited
// brick files that already live in a manual-files-*.cue shard are
// pulled into the brick's derived writes set automatically -- the
// brick author doesn't redeclare what manualFiles already accounts
// for. Same path-prefix shape as _brickPrefixedClaims.
_brickPrefixedManualFiles: {
	for slug, b in bricks {
		(slug): [
			for p in manualFiles
			if strings.HasPrefix(p, b.path+"/") {p},
		]
	}
}

_brickPrefixedReadPaths: {
	for slug, b in bricks {
		(slug): [
			for _, g in generators
			if g.read_from.paths != _|_
			for p in g.read_from.paths
			if strings.HasPrefix(p, b.path+"/") {p},
		]
	}
}

_brickPrefixedReadGlobs: {
	for slug, b in bricks {
		(slug): [
			for _, g in generators
			if g.read_from.path_globs != _|_
			for p in g.read_from.path_globs
			if strings.HasPrefix(p, b.path+"/") {p},
		]
	}
}

_brickDeclaredReads: {
	for slug, b in bricks {
		(slug): [
			if b.reads != _|_
			for p in b.reads {p},
		]
	}
}

_brickDeclaredWrites: {
	for slug, b in bricks {
		(slug): [
			if b.writes != _|_
			for p in b.writes {p},
		]
	}
}

brick_io: [string]: {
	reads: [...string]
	writes: [...string]
}

brick_io: {
	for slug, _ in bricks {
		(slug): {
			writes: list.SortStrings(list.Concat([
				_brickPrefixedClaims[slug],
				_brickPrefixedManualFiles[slug],
				_brickDeclaredWrites[slug],
			]))
			reads: list.SortStrings(list.Concat([
				_brickPrefixedReadPaths[slug],
				_brickPrefixedReadGlobs[slug],
				_brickDeclaredReads[slug],
			]))
		}
	}
}

// AIDR-00097: per-brick "directory contains files" indicator. Reuses
// allPaths (full m/ walk at depths 1-11) -- a brick has files iff
// any allPaths entry starts with `b.path + "/"`. O(bricks * allPaths)
// = ~270 * ~3300 = ~900K iterations; tolerable for a vet pass.
_brickHasFiles: {
	for slug, b in bricks {
		(slug): {
			has_files: bool | *false
			if len([for p in allPaths if strings.HasPrefix(p, b.path+"/") {p}]) > 0 {
				has_files: true
			}
		}
	}
}

// AIDR-00097: every brick whose path contains files must have a
// non-empty derived+declared writes set. The derivation pulls from
// generator paths AND manualFiles, so this rule fires only when a
// brick has files that are accounted for by NEITHER substrate AND
// the brick has no inline `writes` declaration.
//
// Mechanically: file-existence drives the rule; no opt-in flag, no
// `writes: []` shorthand. A truly empty brick directory yields
// has_files == false and the rule is silent.
//
// Struct-shape per AIDR-00095 lesson: violators surface as
// `_emptyBrickWrites.<slug>: field not allowed` rather than the
// uninformative "incompatible list lengths".
_emptyBrickWrites: {
	for slug, _ in bricks
	if _brickHasFiles[slug].has_files
	if len(brick_io[slug].writes) == 0 {
		(slug): "brick directory contains files but no writes are claimed by any generator path, manualFiles entry, or inline declaration"
	}
}
_emptyBrickWrites: close({})

// AIDR-00131: every brick must declare `reads:` explicitly (use
// `reads: []` if no inline file-path reads beyond what the generator
// contract derives). Mirror of `_emptyBrickWrites` with a different
// trigger: there is no on-disk forcing function for reads (a brick
// may legitimately read nothing at the file-path level), so the vet
// fires on field absence rather than on file existence + empty
// derivation.
//
// Required field is on `b.reads` (the inline declaration), not on
// `brick_io[slug].reads` (the derived union). A stamped brick whose
// generator's `read_from` happens to declare nothing at the
// path/glob level would otherwise need to also be hand-marked; the
// universal `reads: []` shape avoids that and catches the case
// where a generator-stamped brick author later adds an inline read
// without declaring `reads`.
//
// Struct-shape per AIDR-00095 lesson: violators surface as
// `_emptyBrickReads.<slug>: field not allowed` rather than the
// uninformative "incompatible list lengths".
_emptyBrickReads: {
	for slug, b in bricks
	if b.reads == _|_ {
		(slug): "brick must declare reads explicitly (use `reads: []` if no inline file-path reads beyond what the generator contract derives)"
	}
}
_emptyBrickReads: close({})

// AIDR-00098 pairwise-write-intersection check is implemented in Go
// at //tenant/library/go/lib/spec/brickcollision. The Go path was chosen over
// CUE-side closure for testability: txtar-fixtured table-driven
// tests via go_test are simpler to author and Bazel-cache natively.
// brick_io (above) remains the data source; the Go check consumes
// the cue-exported brick_io.json and asserts no non-ancestor pair
// shares any write path. See AIDR-00098 (revisit -- spec was for
// CUE-side; the as-built notes the pivot to Go).
