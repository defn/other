# defn Monorepo - Agent Configuration

This file is a table of contents. Each line is a one-liner; rules
that need expansion live in the file, doc, or source header they
constrain. Don't front-load all rules here -- discover them via
the references when the task brings you near.

CLAUDE.md is a symlink to this file (`root/AGENTS.md`). This is the
only AGENTS.md / CLAUDE.md in the repo.

Three documentation surfaces, in priority order:

- Comments / headers in content files -- the default; co-located with the code they constrain.
- `airef/` -- cross-cutting advice ("how we do things" spanning multiple files / dirs); living, updated in place. Create with `mise run airef`.
- `aidr/` -- chronological decision records (immutable history of design choices, with reasoning). Create with `mise run aidr`.

The conventions for each live in their `BUILD.bazel` header and the
creating mise task; the BRICK theory they rest on is in
`kernel/doc/BRICK.md`.

The mise tasks generate the canonical format:

- airef -- `airef/NNNNN-<topic-slug>.md`; H1 title, a `**Last updated**` line; living advice, edited in place. Example: `airef/00007-midas-stamping-model.md`.
- aidr -- `aidr/NNNNN-YYYY-MM-DD-<type>-<topic-slug>.md` where `<type>` is `spec | plan | options | decision | review`; H1 `<Type>: <Topic>`, a `**Date**` line; immutable once written. Example: `aidr/00083-2026-04-27-decision-rename-kit-to-branch-and-lazy-shard-policy.md`.

## Repo-wide rules

- Content in AGENTS.md must be a one-liner, like a table of contents; can reference another document in the repo.
- Daily workflow: stamp -> code -> `mise run hatch` -> `mise run check` -> commit -> push. See `mise tasks`.
- Commit directly to main; record non-obvious decisions with `mise run aidr`.
- CUE is the primary configuration; Bazel is the build system; the workspace lives in `m/`. See `root/README.md`.
- BRICKs are a feedback substrate, not a directory classifier. Trust check / hatch error messages. See `kernel/doc/BRICK.md`.
- Stamp is online (network OK); gen is offline (pure function from workspace state). See header of `tenant/library/go/cmd/gen/service.go`.
- N copies always drift -- use Midas (catalog + template + generator). See the Midas section of `kernel/doc/BRICK.md`.
- Never hand-edit paths claimed by a generator's contract.cue; hand-written files are allow-listed in `kernel/spec/manual-files-*.cue`.
- Always use mise tasks; always bazelisk, never bazel. See `mise tasks`.
- Go code must be a defn CLI sub-command (`tenant/library/go/cmd/<name>/` + `tenant/library/go/lib/<area>/`; tenant-specific under `tenant/<tenant>/go/`). See `kernel/doc/BRICK-GO.md`.
- No bash scripts; use babashka via `bin/bbs`. The only bash in the repo is that wrapper.
- ASCII only in source, docs, commits, and generated output.
- Repeatable manual work -> capture as airef (`mise run airef`), retire when folded into a brick (stamp / generator / mise task / `defn` subcommand).
- Helm chart upgrades: discover-batch-stamp-hatch-evaluate-sync loop, one app at a time. See the `helmupgrade` hatch subcommand (`tenant/library/go/cmd/hatch/helmupgrade/`) plus `mise run helm-bump` / `mise run upgrade`.
- Coordinator dispatch (`defn dispatch`) calls `defn hatch --brick=...`; small humans -> K parallel sub-agents. Per-brick worker I/O is declared in each brick's `dispatch.cue` (schema: `kernel/spec/dispatch`).
- Portability has hard environment constraints (m/ layout, mise toolset/trust, no hardcoded /home/ubuntu, per-machine .bazelrc.workspace) that this repo must satisfy on every machine. See `kernel/doc/PORTABILITY.md`.

## Live (retire-on-fold) recipes

These document manual recipes that should disappear once the brick
layer subsumes them. Capture new manual recipes with `mise run
airef` and list them here.

- Helm chart upgrade workflow -- currently the `helmupgrade` hatch
  subcommand (`tenant/library/go/cmd/hatch/helmupgrade/`) + `mise run
helm-bump`. Folds in fully once a one-shot `defn upgrade
helm-charts` (discovery + batched stamp/hatch loop) lands.

## Where things live

- Build, test, every workflow -- `mise tasks` (each task in `.mise/tasks/` self-documents via its `#MISE description=`).
- Project overview + core tenets + GitOps framing -- [`root/README.md`](README.md).
- BRICK theory (the five registers) -- [`kernel/doc/BRICK.md`](../kernel/doc/BRICK.md); Go patterns -- [`kernel/doc/BRICK-GO.md`](../kernel/doc/BRICK-GO.md).
- Cross-cutting advice -- [`airef/`](../airef/) (`mise run airef` to add).
- Chronological decision history -- [`aidr/`](../aidr/) (`mise run aidr` to add).
- Creating bricks -- `defn stamp --help`; step-by-step in [`kernel/doc/BRICK-CREATE.md`](../kernel/doc/BRICK-CREATE.md), bootstrap in [`kernel/doc/BRICK-BOOTSTRAP.md`](../kernel/doc/BRICK-BOOTSTRAP.md).
- Adding new helm-app -- header of [`tenant/library/go/lib/stamp/helmapp.go`](../tenant/library/go/lib/stamp/helmapp.go); `tenant/<tenant>/app/<name>/app.cue` is the only hand edit; schema in [`kernel/schema/app.cue`](../kernel/schema/app.cue).
- Per-cluster app rendering + deploy -- header of [`tenant/library/k3d/BUILD.bazel`](../tenant/library/k3d/BUILD.bazel); schema in [`kernel/interface/k3d/`](../kernel/interface/k3d/).
- Hatch (reaching equilibrium) -- header of [`tenant/library/go/cmd/hatch/service.go`](../tenant/library/go/cmd/hatch/service.go).
- Gen pipeline (the fixed-point loop) -- [`tenant/library/go/cmd/gen/service.go`](../tenant/library/go/cmd/gen/service.go); generator libs in `tenant/library/go/lib/gen/`.
- AIDR conventions + `mise run aidr` -- header of [`aidr/BUILD.bazel`](../aidr/BUILD.bazel) and [`.mise/tasks/aidr.clj`](../.mise/tasks/aidr.clj).
- AIREF conventions + `mise run airef` -- header of [`airef/BUILD.bazel`](../airef/BUILD.bazel) and [`.mise/tasks/airef.clj`](../.mise/tasks/airef.clj).
- Tool versions + sync targets -- [`kernel/schema/versions.cue`](../kernel/schema/versions.cue) (package comment documents pinning policies).
- File tag taxonomy -- header of [`kernel/tagged.bzl`](../kernel/tagged.bzl).
- Typed-tree manifest (validates the git filesystem) -- [`kernel/manifest/manifest.cue`](../kernel/manifest/manifest.cue).
- Adding a new tenant + the portability contract -- [`kernel/doc/PORTABILITY.md`](../kernel/doc/PORTABILITY.md) and [`kernel/doc/BRICK-BOOTSTRAP.md`](../kernel/doc/BRICK-BOOTSTRAP.md).
- Cross-tenant literal vet -- [`tenant/library/go/cmd/check/crosstenantlit/`](../tenant/library/go/cmd/check/crosstenantlit/) (logic in `tenant/library/go/lib/spec/crosstenantlit/`).

## Constants

- CUE module -- `github.com/defn/defn`.
- Go module -- `github.com/defn/defn/m`.
- Bazel module -- `defn`.
- Platform support -- Linux (Ubuntu 24.04 / 26.04 LTS); macOS for bootstrap only.
- Languages -- Go (rules_go + gazelle), Python (rules_python + rules_uv), JS/TS (aspect_rules_js + aspect_rules_ts + pnpm), Java (rules_java + GraalVM native-image), Containers (rules_oci + crane), Scripting (babashka).
