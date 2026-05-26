---
name: sp-bricks
description: Implementation layer: stamp -> hatch -> check; no deliberation
---

# sp-bricks

## Overview

Execute a chosen option from an AIDR. Stamp new bricks, hand-edit the
files those bricks declare hand-editable, run `mise run hatch` until
equilibrium, run `mise run check` until green. Commit per brick.

**Equilibrium is the contract.** The lattice + manifest + generator
contracts + 100% `fmt_test` and `tagged_file` coverage are the test.
There is no separate self-review step. Skip TDD prose, RED-GREEN-
REFACTOR ceremony, "verification before completion" rituals -- those
are subsumed by `mise run check`.

**Equilibrium runs without asking.** `mise run hatch` + `mise run
check` (or `--ignore-unclean-workarea` while developing) is the
feedback loop, and it must hold at every stable point. Run it
proactively after any coherent batch of edits -- don't ask the user
first. Skip only when mid-landing of a multi-step change where
intermediate state is intentionally inconsistent. This applies to
sp-options (after minting an AIDR), sp-review (between fix-in-place
batches and at end of questionnaire), and sp-bricks (after each
hand-edit batch and before commit).

**Announce at start:** `Using sp-bricks to implement <option> from AIDR-NNNNN.`

## When to invoke

- After `sp-options` has produced an AIDR and the user has fixated
  on one option.
- For trivial direct fixes (typo, single-line bug) where invoking
  `sp-options` first would be theatre.
- When restamping or refactoring an existing brick and the brick
  machinery already constrains the change shape.

Do **not** invoke when:

- The option is unclear or contested -- go to `sp-options` first.
- The change spans more than ~5 bricks across unrelated areas
  (split into multiple AIDRs / multiple `sp-bricks` invocations).

## Process

1. **Read the AIDR.** Open the file the user named (or the most
   recent under `m/aidr/` if they didn't name one). Note the chosen
   option and its declared brick footprint.

2. **For each new brick, run `defn stamp <kind> <path>`.**

   ```
   defn stamp helm-app <name> --chart-repo URL --chart-name CHART --chart-version V --desc "..."
   defn stamp go-cmd <path> --desc "..."
   defn stamp skill <name> --desc "..." [--subdirs scripts,prompts,...]
   ...
   ```

   Stamp is idempotent. Running it a second time with the same args
   is a no-op. Re-stamping with new args updates affected entries.

3. **Hand-edit only the files the brick declares hand-editable.**
   Per-brick contracts list claimed (generated) paths in
   `go/internal/gen/<brick>/contract.cue`; the rest are yours to
   write. Common hand-edited shapes:
   - `app/<name>/app.cue` for helm-app bricks.
   - `*.go` source files for go-cmd / go-lib bricks.
   - `SKILL.md` for skill bricks.
   - `tenant/<name>/catalog/*.cue` for per-tenant catalog instance data.

   Never hand-edit a path the contract claims; the next `hatch` will
   overwrite it. If you find yourself wanting to, the brick shape is
   probably wrong -- escalate via `sp-options`.

3a. **Prefer library functions over hand-rolled OS / process / workarea
   plumbing.** When an edit needs to spawn a subprocess, capture stdout,
   read/write workspace files, walk git-tracked files, mutate
   environment, or interact with the filesystem at a tricky boundary,
   use the helper that already owns that invariant -- do not inline an
   `exec.Command(...).Run()`, an `os.Pipe()` capture, an `os.Stat`
   walk, or an `os.Setenv` toggle. Re-implementing these inline grows
   N copies that drift; a regression in one (e.g. a 64 KiB pipe-buffer
   deadlock when bazel writes too much to stdout) then has to be hunted
   and fixed N times.

   Current helpers (extend rather than bypass):

   - **Subprocess + captured stdout** -- `go/internal/runner` (`runner.Run`,
     `runner.Output`, `runner.Capture`). The pipe drainer, stderr
     inheritance defaults, and live-tee semantics are owned here.
   - **Bazel / mise / shell wrappers** -- `gen.Context.BazelTest`,
     `BazelBuild`, `Sh`, `ShRun`, `MiseExec` (`go/internal/gen/exec.go`).
     These delegate to `runner` so the fix points stay singular.
   - **Workspace I/O** -- `gen.WriteIfChanged`, `gen.ParallelN`,
     mtime-preserving writes; never write a tracked file with a bare
     `os.WriteFile` if the byte-identical path matters (it almost
     always does -- see AIDR-00058).
   - **Git-tracked file walks** -- `genCtx.Sh("git", "ls-files")` then
     iterate; never `filepath.Walk` to enumerate tracked files (you
     will pick up bazel-bin and untracked junk).

   If no helper covers your case, **add one to the relevant package
   first, then call it** -- single fix point. Mention the new helper in
   the commit message; if its boundary is non-obvious, mint an AIDR.

4. **`mise run hatch`.** Reach equilibrium. Read the output:
   - `idempotent` means no changes -- you're done generating.
   - `<N> files changed` means one more pass. Re-run hatch until
     idempotent (usually 1-2 iterations).
   - On error: stop. Surface the error verbatim. Do not "try
     something else" -- the error names the file and invariant.

   **`git add` new files before hatch.** The lattice/manifest gen
   walks git-tracked files only, not the working tree. A brand-new
   untracked file (e.g. an AIDR you just minted, a stamped brick's
   first scaffolded source file) is invisible to gen and hatch will
   falsely report `idempotent`. `git add <new-paths>` (or `git add
   -N` for staging-without-content) before `mise run hatch` so the
   sidecars actually pick the file up. Symptom of getting this wrong:
   `mise run check` later fails with an orphan / missing-claim /
   missing-tagged_file error on the file you thought hatch had
   incorporated.

5. **`mise run check -- --ignore-unclean-workarea`.** Verify:
   - Manifest validation: every file conforms to its `#Repo` schema
     entry.
   - Spec contracts: 0 orphans, 0 missingClaims, 0 manualClaimed
     collisions.
   - 100% `fmt_test` and `tagged_file` coverage.
   - Spec tests pass.

   On error: stop. The error message names the failing path. Fix the
   path or update the schema/contract. Do not skip checks.

6. **Commit per brick.** Use the repo's existing commit conventions
   (read recent `git log --oneline`). Message focuses on **why**, not
   **what**. One brick per commit when feasible; tightly coupled
   brick groups can co-commit.

7. **Final `mise run check`** without `--ignore-unclean-workarea`
   verifies the workspace is clean. Push.

## What this skill does NOT do

- **Does not deliberate.** No "let me think about whether this is the
  right approach" -- that was `sp-options`'s job, in the AIDR.
- **Does not self-review.** The brick machinery's checks are the
  review. `sp-review` runs at the fixed point of all bricks done,
  not between brick steps.
- **Does not write tests separately.** Spec lattice, contracts, and
  fmt/tagged coverage ARE the tests. Adding feature tests beyond
  what the brick contract requires is scope creep.
- **Does not skip the failure surface.** If `hatch` or `check` fails,
  read the error and fix the named file. Never bypass with
  `--no-verify`, never delete the failing file, never edit the spec
  test to silence a real orphan.

## Subagents (optional)

If subagents are available AND the AIDR identifies independent
bricks (no shared catalog edits, no shared manual-files entries):

- Dispatch one subagent per brick. Each gets isolated context: the
  AIDR text, the brick path, the brick's contract file, and the
  files it owns. No conversation history.
- Wait for all to finish. Then run `mise run hatch` and `mise run
  check` once at the top level.

If the bricks share a catalog file (e.g. multiple skills appending
to `kernel/catalog/skills.cue`), serialize -- parallel writers will
collide. Default to serial.

Future kernel work to make brick-isolated parallel safe is tracked
in a separate AIDR; until then, **default-serial**.

## Failure modes to escalate

Stop and ask the user (or invoke `sp-options`) when:

- A brick won't reach equilibrium after 3 hatch iterations.
- A `mise run check` failure points at a file the AIDR didn't
  identify (option mis-modeled the footprint).
- A generator's claim conflicts with a manual-files entry
  (manualClaimed != []) and resolving requires a design call.
- A schema in `kernel/manifest/manifest.cue` would need to change to
  accommodate the work. Schema changes are design decisions, not
  implementation; mint a `spec`-type AIDR.

## Cross-references

- `sp-options` -- the supervisory layer that produced the AIDR you
  are implementing.
- `sp-review` -- runs at the fixed point of all bricks done.
- `m/aidr/00045-stamp-online-offline-split-and-catalog-mutation-generalization.md`
  -- stamp vs gen boundary.
- `m/aidr/00071-kernel-tenant-decoupling.md` -- kernel/tenant
  separation principles.
