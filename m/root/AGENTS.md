# defn Monorepo - Agent Configuration

This file is a table of contents. Each line is a one-liner; rules
that need expansion live in the file or AIDR or AIREF they
constrain. Don't front-load all rules here -- discover them via
the references when the task brings you near.

CLAUDE.md is a symlink to this file. This is the only AGENTS.md /
CLAUDE.md in the repo.

Three documentation surfaces, in priority order:

- Comments in content files -- the default; co-located with the code they constrain.
- `m/airef/` -- cross-cutting advice ("how we do things" spanning multiple files / dirs); living, updated in place.
- `m/aidr/` -- chronological decision records (immutable history of design choices, with reasoning).

See [AIREF-00001](airef/00001-documentation-organization.md) for the policy.

## Repo-wide rules

- Content in AGENTS.md must be a one-liner, like a table of contents; can reference another document in the repo.
- Daily workflow: stamp -> code -> `mise run hatch` -> `mise run check` -> commit -> push. See [AIREF-00002](airef/00002-daily-workflow.md).
- Commit directly to main; AIDR for non-obvious decisions; TODO entries are skill-tagged. See [AIREF-00003](airef/00003-work-recording.md).
- CUE is the primary configuration; Bazel is the build system; the workspace lives in `m/`. See [AIREF-00004](airef/00004-configuration-philosophy.md).
- BRICKs are a feedback substrate, not a directory classifier. Trust check / hatch error messages. See [AIREF-00005](airef/00005-bricks-as-feedback-substrate.md).
- Stamp is online (network OK); gen is offline (pure function from workspace state). See [AIREF-00006](airef/00006-stamp-vs-gen-boundary.md).
- N copies always drift -- use Midas (catalog + template + generator). See [AIREF-00007](airef/00007-midas-stamping-model.md).
- Never hand-edit paths claimed by a generator's contract.cue. See [AIREF-00008](airef/00008-generator-output-paths-are-claimed.md).
- Always use mise tasks; always bazelisk, never bazel. See [AIREF-00009](airef/00009-build-tooling.md).
- Go code must be a defn CLI sub-command (`m/go/cmd/<area>/<name>/` + `m/go/internal/<area>/<name>/`). See [AIREF-00010](airef/00010-go-code-must-be-defn-cli-subcommand.md).
- No bash scripts; use babashka via `m/bin/bbs`. See [AIREF-00011](airef/00011-scripting-policy.md).
- ASCII only in source, docs, commits, and generated output. See [AIREF-00012](airef/00012-character-encoding-ascii-only.md).
- Repeatable manual work -> capture as airef, retire when folded into a brick (stamp / generator / mise task / `defn` subcommand). See [AIREF-00014](airef/00014-manual-work-as-airef-captured-then-folded-into-bricks.md).
- Helm chart upgrades: discover-batch-stamp-hatch-evaluate-sync loop, one app at a time. See [AIREF-00017](airef/00017-helm-chart-upgrade-workflow.md).
- Coordinator dispatch (`defn dispatch`) is the AIDR-00132 caller of `defn hatch --brick=...`; small humans -> K parallel sub-agents. See [AIREF-00018](airef/00018-coordinator-dispatch-walkthrough.md).
- Fork portability has hard environment constraints (m/ layout, mise toolset/trust, no hardcoded /home/ubuntu, per-machine .bazelrc.workspace); a lift must satisfy them. See [AIREF-00019](airef/00019-portability-hard-constraints-the-fork-lift-contract.md).

## Live (retire-on-fold) AIREFs

These airefs document manual recipes that should disappear once the
brick layer subsumes them. Don't grow this list silently; each entry
has a matching `~/TODO.md` follow-up.

- [AIREF-00017](airef/00017-helm-chart-upgrade-workflow.md) -- helm
  chart upgrade workflow. Folds in once `defn upgrade helm-charts`
  (discovery + batched stamp/hatch loop) lands as a brick subcommand.

## Where things live

- Build, test, every workflow -- `mise tasks` (each task self-documents via its `#MISE description=`).
- Cross-cutting advice index -- [`m/airef/`](airef/).
- AIDR index (chronological decision history) -- [`m/aidr/`](m/aidr/).
- Configuration philosophy + GRAFT framing -- [`m/aidr/00065-graft-whitepaper.md`](m/aidr/00065-graft-whitepaper.md).
- Creating bricks -- `defn stamp --help`; design in AIDR-00045.
- Adding new helm-app -- header of [`m/go/internal/stamp/helmapp.go`](m/go/internal/stamp/helmapp.go); `app/<name>/app.cue` is the only hand edit.
- Per-cluster app rendering + deploy -- header of [`m/k3d/BUILD.bazel`](m/k3d/BUILD.bazel); design in AIDR-00067.
- Hatch (reaching equilibrium) -- header of [`m/go/cmd/hatch/service.go`](m/go/cmd/hatch/service.go).
- AIDR conventions + `mise run aidr` -- header of [`m/aidr/BUILD.bazel`](m/aidr/BUILD.bazel).
- AIREF conventions + `mise run airef` -- header of [`m/airef/BUILD.bazel`](m/airef/BUILD.bazel).
- Tool versions + sync targets -- [`m/schema/versions.cue`](m/schema/versions.cue) (package comment documents pinning policies).
- File tag taxonomy -- header of [`m/tagged.bzl`](m/tagged.bzl).
- Forking the kernel + adding a new tenant -- "Fork procedure" section in [`m/aidr/00071-kernel-tenant-decoupling.md`](m/aidr/00071-kernel-tenant-decoupling.md).
- Cross-tenant literal vet (SPEC-00352) -- [`m/aidr/00102-...md`](m/aidr/).
- Kernel/tenant decoupling rationale -- [`m/aidr/00071-kernel-tenant-decoupling.md`](m/aidr/00071-kernel-tenant-decoupling.md).
- Project overview + version sync narrative -- [`README.md`](README.md).

## Constants

- CUE module -- `github.com/defn/defn`.
- Go module -- `github.com/defn/defn/m`.
- Bazel module -- `defn`.
- Platform support -- Linux (Ubuntu 24.04 / 26.04 LTS); macOS for bootstrap only.
- Languages -- Go (rules_go + gazelle), Python (rules_python + rules_uv), JS/TS (aspect_rules_js + aspect_rules_ts + pnpm), Java (rules_java + GraalVM native-image), Containers (rules_oci + crane), Scripting (babashka).
