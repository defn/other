# Kernel Portability Contract

This document is the practitioner's reference for the
"deterministic-after-bootstrap" contract between `kernel/` +
`tenant/library/` (the substrate) and any downstream fork. The
contract was specified in AIDR-00138 and exercised end-to-end in
AIDR-00139; this file captures the working rules that emerged so
new contracts, contracts changes, and tests stay portable from
day one.

The substrate, the bundle, the fork

The substrate is `kernel/` plus `tenant/library/`. It is the
code, schema, and template content that every fork needs to
function. The bundle is the rsync'd copy that `defn bootstrap`
delivers into a fork's working directory (plus workspace
scaffolding, bin/, gen/, go/, .devcontainer, .mise/tasks). A
fork is any repo that received that bundle and runs `mise run
check` against it under its own CUE and Go module names. A fork
is well-formed when its `mise run check` is green and its
`mise run hatch` is idempotent.

The bootstrap mechanism is `defn bootstrap` (the `init` action,
ported from the babashka stand-in per AIDR-00139 Tier 1). It
rsyncs the bundle, rewrites the upstream CUE + Go module names,
stubs the fork's leaf tenant, regenerates `.bazelrc.workspace`
for the fork's filesystem location, and commits in the fork's
parent directory.

Determinism after bootstrap

The contract is: `target/kernel/<path>` equals
`rewrite(source/kernel/<path>)`, where `rewrite` is the literal
string replacement of `github.com/defn/defn/m` with the fork's
Go module followed by `github.com/defn/defn` with the fork's CUE
module. Two classes of files are exempt: `.pb.go` files embed
length-prefixed binary protobuf descriptors that the naive
string replace would corrupt, and path-dependent files like
`.bazelrc.workspace` are regenerated in-target rather than
copied. Both exclusions are encoded in `defn bootstrap`'s logic
and are part of the contract.

The volatile zone: top-level `var/` (AIDR-00145)

All workspace-derived generator output (the manifest/lattice
snapshots and the sharded lattice payload) lives in a top-level
`var/` dir -- a peer to `kernel/` and `tenant/`. `var/` is
git-tracked but **NOT bundled** by `defn bootstrap`: a fork never
receives it and grows its own on first `mise run hatch`. This keeps
`kernel/` and `tenant/` changing only on structural edits, never on
regen churn, and makes both rewrite-deterministic with no per-file
allow-list. CUE files under `var/` (e.g. `gen-lattice.cue` is
`package spec`) are re-projected into their declared kernel package
at load time by `gen.buildOverlay`'s var overlay; the manifest
validation calls `ctx.RefreshOverlay()` first because cuetree /
speclattice rewrite those files mid-pipeline after the overlay was
snapshotted at `NewContext`.

The not-bundled `var/` creates a bootstrap chicken/egg: any bundled
file that references a `var/` path needs that path to exist before
the fork's first hatch (which is what populates `var/`). `defn
bootstrap` therefore **seeds** the minimal `var/` files the first
hatch's bazel analysis and CLI resolution need:

- `var/BUILD.bazel` + `var/lattice/BUILD.bazel` -- the two
  hand-written, content-independent (glob + tagged_package) skeletons
  the generators don't emit.
- `var/lattice/default_tenant.json` -- `active-tenant`
  (`kernel/lib/defn.clj`) reads this to pick which namesake CLI to
  build/run; without it the fork's first `defn-bin!` falls back to
  `defn` and tries to run the absent `tenant/defn/go/cmd/defn`.
- `var/gen-chart-digests.cue` (empty `package catalog` form) --
  `kernel/catalog/BUILD.bazel`'s `catalog_files` references
  `//var:gen-chart-digests.cue` by explicit label; analysis fails
  without it.

Each seed is force-written and refreshed by the fork's first hatch.
When adding any bundled reference to a `var/` path, seed it here too.

Writing portable contracts (`contract.cue`)

Every catalog field that a contract binds with `field: _` must
be present in the lattice JSON, even if absent from the catalog.
The `buildLattice` policy is "emit empty map on missing": when a
fork's catalog has no `aws_tofu_apps`, the lattice shard still
contains `aws_tofu_apps: {}` so the contract's comprehension
evaluates to an empty list rather than `_|_`. Unbound `_`
becomes `_|_` when iterated; the propagation is silent and
catastrophic, producing thousands of bogus orphans 600+ stack
frames deep in CUE evaluation. If you add a new `<field>: _`
binding to any contract, add the corresponding lattice exposure
in `lattice.go::buildLattice` in the same change.

A contract must never hardcode a tenant path. Use
`default_tenant` from the catalog and derive paths from it. The
infra and awstofu contracts demonstrate the pattern: they iterate
catalog maps and prefix paths with `default_tenant`.

Writing portable tests (`spec_test.go`, `*-test.clj`)

Tests that need to know the workspace's CUE or Go module name
must read it from `cue.mod/module.cue` and `go.mod`, not from a
literal `github.com/defn/defn` constant. `Lattice.CUEModule()`
and `Lattice.GoModule()` parse those files; the existing
SPEC-00008 / SPEC-00009 / SPEC-00280 tests use them.

Tests that assert defn-only invariants (e.g. SPEC-00274's orphan
midas interface check) gate on rewrite-stable signals: the
presence of `tenant/defn` as a literal directory name, for
example, is never touched by the module-path rewrite, so the
gate works in both upstream and forks.

Tests with txtar fixtures that exercise module-path-sensitive
code must add an explicit `go.mod` to the fixture. Otherwise the
fixture inherits the host workspace's module name, and the test
passes in defn but fails in a fork (or vice versa).

The fork-portability probe

`mise run check-fork` is the canonical fork-portability probe.
It runs `defn bootstrap` into a fresh /tmp directory, then runs
`mise run hatch` + `mise run check` inside the fork; a green
result validates the contract holds. The probe is opt-in via
`mise run check --with-fork` because its wall-clock (~20 min
from a cold cache, the fork has to build defn from source) is
too expensive to gate every host check on. Run it manually
whenever you touch `kernel/` substrate; the host's `mise run
check` covers cheaper static guards (zsh-safety, contract-
lattice coverage, fmt, mtime idempotence, manifest validation).

For a long-lived fork checkout, `defn bootstrap --verify
--target=<fork>` runs three layers of analysis:

1. Source-SHA drift: recorded "bootstrap from defn@<sha>" in the
   fork's parent git history vs host HEAD.
2. Bundle drift: `git diff --name-only <recorded>..<HEAD>`
   restricted to the bundle pathspec -- which source files would
   propagate to the fork on re-bootstrap.
3. Rewrite-equivalence: `git worktree add` at recorded SHA,
   re-run the bootstrap rewrite into a temp dir, diff vs actual
   target with the generator-claimed paths + one-shot stamp
   paths allow-listed out. The surviving diff is the set of
   bundle files the fork has edited post-bootstrap; re-bootstrap
   would overwrite them. The intersection with layer 2 is the
   re-bootstrap conflict set.

Exit 0 when the fork has no local edits to bundle files (re-
bootstrap is safe); nonzero when fork-edits exist and would be
lost. Adds ~30s wall-clock for the worktree + rewrite step. CI
gate for fork repos, and a "should I re-bootstrap, and what will
I lose?" check on an operator workstation.

Common coupling traps

Tenant defaults in catalog files. `kernel/catalog/catalog.cue`
declares `default_tenant: *"defn" | string`. Without a fork's
own `default-tenant.cue` overriding this, the gen pipeline reads
`"defn"` as the default and stamps `tenant/defn/...` paths into
a fork that has no defn tree. The fork's `tenant/other/catalog/
default-tenant.cue` (created by `defn bootstrap`) pins the
override.

`.pb.go` descriptor encoding. Generic text-replace breaks
length-prefixed binary string literals embedded in
protobuf-generated Go files. The rewrite skips `*.pb.go`
explicitly; the package's self-name string in the descriptor
ends up stale in the fork (still says `github.com/defn/defn`)
but runtime-harmless for everything we care about (no
cross-package descriptor resolution).

Bazel does not respect `.gitignore`. The host's `.gitignore`
excludes `/other/` from git, but Bazel still descends into
`m/other/m/BUILD.bazel` and chokes on packages it didn't
expect. `.bazelignore` is the Bazel-side directive and must be
maintained separately.

Path-dependent files. `.bazelrc.workspace` encodes absolute
paths for HOME, MISE_CONFIG_FILE, and `sandbox_writable_path`.
Copying the host's version blindly points the fork's Bazel
sandbox at the host's mise.toml. `defn bootstrap` invokes
`bin/bootstrap-bazelrc` in the target post-copy to regenerate
this file for the fork's filesystem location.

mise.toml task includes. The host's mise.toml lists task
include dirs for every tenant. After bootstrap the fork's
mise.toml drops `tenant/boot/` and `tenant/defn/` lines (those
tenants don't ship in the bundle); failing to drop them means
mise warns about missing include paths.

References

AIDR-00138 spec: the portability contract specification.

AIDR-00139 retrospective: every coupling the session uncovered,
the fix, and the remaining TODOs (Tier 1 consolidation, Tier 2
D5 follow-ups, Tier 3 hardening, Tier 4 nice-to-haves).

AIDR-00071: the original kernel/tenant decoupling rationale.
This is where the "library is universal; defn/boot/other are
leaf tenants" framing comes from.

AIDR-00083: the manual-files sharding precedent that the
tenant-spec overlay (D5.2) extends.
