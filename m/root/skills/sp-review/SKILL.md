---
name: sp-review
description: Terminal layer: code + security review at brick fixed point -> review AIDR
---

# sp-review

## Overview

Run code review and security review on a clean diff. Dispatch two
subagents in parallel, each with isolated context (the diff plus the
relevant brick contracts -- nothing else). Mint an AIDR with their
findings, severity-tagged. **Then immediately walk the user through
the findings as a questionnaire** -- one finding at a time, with a
short bulleted choice list. Don't drop the user back to a free prompt
after writing the AIDR; the questionnaire is the deliverable.

Trivial fixes land in place during the questionnaire (the agent
applies them immediately); non-trivial ones get an `sp-options`
follow-up; everything else is recorded in the review AIDR's Triage
section.

**Announce at start:** `Using sp-review to run terminal review on the brick fixed point.`

## When to invoke

- `mise run check` is clean.
- The diff against `origin/main` is non-trivial (more than a typo,
  more than one brick changed, or the change touches kernel
  schemas / generators).
- Before a release branch is cut (when that becomes the workflow).

Do **not** invoke:

- Mid-implementation -- review at fixed point, not between brick
  steps.
- For trivial diffs the brick machinery already verified (e.g. a
  one-line bug fix that produced a clean `mise run check`). The
  brick checks ARE the trivial-diff review.

## Process

1. **Verify fixed point.** `mise run check` must pass clean (no
   `--ignore-unclean-workarea`). If dirty, route the user back to
   `sp-bricks` to finish.

2. **Compute diff scope.** `git diff origin/main..HEAD --stat` for
   shape; `git diff origin/main..HEAD` for content. Identify:
   - Which bricks changed (`grep` modified paths against
     `kernel/catalog/bricks.cue`).
   - Which generators ran (look at modified `gen-*.cue` files).
   - Which `manual-files.cue` / `convention-contracts.cue` entries
     moved.
   - Which AIDRs the diff implements (via commit messages or
     `sp-options`-minted AIDRs).

3. **Probe the work end-to-end.** The work was designed to prevent
   some class of error. Before dispatching reviewers, try to
   actually trigger that class -- if you can, the substrate isn't
   finished. Two passes:

   **3a. Negative tests against the new invariant.** For each
   constraint the diff introduces (a strict schema field, a closed
   struct, a regex pattern, a `manualFiles` entry, a contract
   claim), construct a deliberate violation in a temp file or
   throwaway commit. Run the relevant check (`mise run check`,
   `bazelisk test //kernel/spec:contracts_vet`, `cue vet`). The
   check should fail with a precise error naming the violation.

   - If it fails: the invariant works. Move on.
   - If it passes: the invariant is incomplete. Strengthen it (or
     add a sibling invariant) until the violation surfaces.
   - Document any violation that surprised you (the class wasn't
     in your design space) -- those become candidates for new
     schemas in step 3b.

   Examples of probes:
   - For a new closed struct: add an extra field, a typo'd
     sub-field, a wrong type at each leaf, a missing required
     field, an empty/regex-violating string.
   - For a new lattice claim: claim a non-existent path, claim a
     path another generator already claims, omit a path the
     generator actually writes.
   - For a new convention regex: add a misnamed file in the
     covered dir, confirm it orphans.

   **3b. Generalize the manual fixes to schemas.** During the
   work, you probably caught and fixed bugs manually -- a stale
   contract entry, a missing test argument, a typo'd field. Each
   of those is one occurrence of a class. Write a CUE invariant or
   test that detects the class, run it against the whole repo,
   keep it if it surfaces additional instances or seems likely to
   catch future drift.

   Pattern for a new invariant:

   ```cue
   // <classname>: <one-sentence description of the class>
   _<classname>: [
       for ... in ...
       if <violating predicate> {<offending entry>},
   ]
   _<classname>: []
   ```

   The trailing `_<classname>: []` is the assertion: any non-empty
   value fails unification.

   Run the new invariant; observe the result:
   - **Catches additional instances**: keep it; commit alongside
     the manual fixes for those instances.
   - **Catches nothing today, but the class is real**: keep it as
     a guard against future drift.
   - **Catches nothing and the class is implausible**: drop it;
     don't add weight.

   Examples of classes this skill has surfaced before:
   - Test args missing a generator's contract.cue (coverage gap)
     -> `_unloadedGenerators` invariant.
   - Generator field key mismatch (typo) ->
     `_generatorKeyMismatch` invariant.
   - Stale path in a contract that doesn't match the code -- this
     is generally caught indirectly via multi-writer detection
     once the test surface is complete.

   The invariants you keep land in the relevant schema file
   (`kernel/spec/contracts-schema.cue`, `kernel/spec/lattice-
   schema.cue`, etc.) with a comment explaining the class.

4. **Dispatch the two reviewers in parallel.** Each subagent gets:
   - The full diff (`git diff origin/main..HEAD`).
   - The list of changed bricks plus their contract files.
   - The relevant AIDR(s).
   - The output of step 3 (probe results + any new invariants
     added). Reviewers should know what's been mechanically
     verified so they can focus on the human-judgment part.
   - The reviewer prompt template from
     `root/skills/sp-review/prompts/`:
     - `code-reviewer.md` for the code subagent.
     - `security-reviewer.md` for the security subagent.

   Each subagent has **no other context** -- no conversation
   history, no other agent's output. Returns a structured findings
   report (template inside each prompt).

5. **Mint the review AIDR.**

   ```
   mise run aidr -- review "<topic>"
   ```

   The task auto-injects today's date into the filename and body
   `**Date**` line, and renders the H1 as `Review: <Topic>`. Body:

   ```markdown
   # AIDR-NNNNN: Review: <Topic>

   **Date**: YYYY-MM-DD

   ## Diff scope

   - Bricks changed: ...
   - AIDRs implemented: [AIDR-NNNNN](NNNNN-...md)
   - Lines: +X / -Y across N files

   ## End-to-end probe (step 3)

   - Negative tests run: <list>
   - Invariants added: <list, with what each detects>
   - Bugs found by invariants: <list, with where they were fixed>
   - Gaps observed (classes the invariants don't yet catch): ...

   ## Code review findings

   <subagent output, severity-tagged>

   ## Security review findings

   <subagent output, severity-tagged>

   ## Triage

   To be filled in by the user. Each finding -> {accept, fix-in-place,
   fix-via-options, ignore-with-rationale}.
   ```

6. **Walk findings as a questionnaire.** Don't drop the user back to
   a free prompt after writing the AIDR -- step through findings
   sequentially. Each finding gets two parts:

   **6a. Present the finding.** One short paragraph: file:line, what
   the issue is, the trip path or threat, and a one-line shape of the
   fix. No padding.

   **6b. Present the option set with tradeoffs and a recommendation.**
   Don't just list `a) Fix b) Punt c) Accept d) Ignore` -- the user
   asked for help making a decision, not a multiple-choice quiz. For
   each option:

   - 1-2 sentences on what choosing it actually does (cost, what it
     touches, what it leaves open).
   - When relevant, the failure mode the option doesn't close
     (e.g. "fix-in-place minimal version leaves filename-injection
     open").

   Then end with a **recommendation** in bold: which option you'd
   choose and why -- the tradeoff that tipped it, in 1-3 sentences.
   The recommendation is not a vote; it's reasoning the user can
   accept, reject, or redirect. Format:

   ```
   **Recommendation: (a).** Cost of the patch is much lower than
   the cost of leaving a latent silent-corruption path in shared
   infrastructure. Findings #N and #M naturally fold in -- same
   helper, same review pass.
   ```

   Default option set (tailor per finding when defaults don't fit):

   ```
   a) Fix-in-place -- agent applies immediately, continues to next finding
   b) Fix-via-options -- mint a follow-up sp-options AIDR for redesign
   c) Accept -- record as accepted in the review AIDR Triage section
   d) Ignore -- discard without record
   ```

   Always preserve the `a) / b) / c)` shortcuts so the user can reply
   with a single letter. Insert a blank line before the first option
   and after the last option for terminal-readability.

   Skip the tradeoff write-up only when an option is unambiguously
   right (e.g. typo fixes, dead-code deletion). When in doubt,
   include it -- the user is delegating judgment, not transcription.

7. **Annotate the implemented spec on every fix-in-place.** When a
   fix lands during the questionnaire, append (or update) an
   `## As-built deltas` section in the AIDR being reviewed (the
   *implemented* AIDR, not the review AIDR). Each entry: the original
   spec language and the change made. The implemented AIDR becomes
   self-contained -- a future reader sees both what was planned and
   what got adjusted during review without having to follow links to
   the review AIDR. Apply the annotation immediately after each fix
   so the spec is durable even if the session is interrupted.

8. **Reach equilibrium between batches and at end.** After any
   coherent batch of fix-in-place edits (typically when finishing a
   group of related findings or at the end of the questionnaire),
   `git add` any new files (the review AIDR, any new AIDRs minted
   for follow-up options), then run `mise run hatch` and `mise run
   check -- --ignore-unclean-workarea`. Don't ask first; this is the
   always-on equilibrium contract. Skip only when mid-landing.

9. **Stop after the questionnaire.** Once every finding is triaged
   and equilibrium is verified, summarize what landed (fix-in-place
   changes, accepted findings, any `sp-options` AIDRs minted) and
   ask whether to commit. Don't auto-commit.

## OS / process / workarea boundaries (use during step 4)

A specific class of finding to surface in code review: hand-rolled
implementations of subprocess invocation, stdout capture, env mutation,
or workspace I/O where a library helper exists. Boundary conditions in
these areas are tricky to get right (pipe-buffer deadlocks, stderr
ordering, mtime-preservation, signal propagation, env-var leakage), and
each inline copy is a place a future regression will hide.

Reviewer should flag, with severity at least medium:

- `exec.Command(...).Run()` / `.Output()` / `.CombinedOutput()` outside
  `go/internal/runner/` and the thin wrappers in
  `go/internal/gen/exec.go`. Should call `runner.Run` /
  `runner.Output` instead.
- `os.Pipe()` + `os.Stdout = w` patterns outside `runner.Capture`.
  Each is a deadlock waiting to happen if the wrapped function spawns
  a subprocess that inherits stdout (e.g. bazel test, which can write
  >64 KiB before exiting).
- `cmd.Stdout = ...` / `cmd.Stderr = ...` set to anything other than
  `os.Stdout`/`os.Stderr` or a `bytes.Buffer` populated entirely
  in-process. Pipes set here without a concurrent drainer deadlock.
- `os.WriteFile` of a git-tracked file when `gen.WriteIfChanged` would
  preserve mtime on byte-identical content. Silent mtime touches break
  Bazel's fast-path cache (AIDR-00058).
- `filepath.Walk` over the working tree to find "tracked" files.
  Should be `git ls-files` via `genCtx.Sh`.
- `os.Setenv` / `os.Unsetenv` outside narrow test setup. Mutates global
  process state; concurrent code in the same process sees the change.

When a finding lands in fix-in-place during the questionnaire, the fix
is "route the call through the existing helper" -- not "re-implement
the boundary correctly inline." If no helper exists, the fix is "add
the helper, then route through it." A diff that consolidates a third
copy into a helper is strictly preferred over a diff that fixes the
third copy in place.

## End-to-end checks (use during step 3)

The probe + experimental-schema pass works best when paired with a
checklist of properties the substrate is supposed to maintain.
Apply whichever apply to the diff:

- **Manifest closedness**: `mise run check` must pass without
  `--ignore-unclean-workarea`. Every git-tracked file fits a
  `#Repo` schema entry.
- **Lattice consistency**: `bazelisk test //kernel/spec:lattice_schema_vet`
  passes. The lattice payload conforms to its schema.
- **Contract coverage**: every `go/internal/gen/<name>/contract.cue`
  on disk is loaded by `contracts_vet` (the
  `_unloadedGenerators` invariant). Missing args = silent drift.
- **No unannounced multi-writers**: every path in two contracts'
  `paths` lists appears in `kernel/spec/known-shared.cue` with a
  reason and consolidate plan.
- **Manual / claimed disjoint**: a file is either hand-edited
  (in a `manual-files-*.cue` shard) or generator-claimed -- never
  both.
- **Schema close()d where claims are known**: any new
  `#X: { ... }` should be `#X: close({ ... })` unless the open
  shape is intentional (e.g. `manualFiles` allows arbitrary string
  paths). Open structs invite drift.
- **Round-trip a stamped brick**: if the diff adds a brick kind
  or stamper, run `defn stamp <kind> <path>` on a throwaway path,
  observe equilibrium, then `git clean -fd` the throwaway. The
  stamp -> hatch -> check loop is the user's actual flow.
- **Empty-tenant probe**: `bazelisk test
  //kernel/spec:empty_tenant_probe` passes. Ensures kernel-side
  changes don't accidentally couple to a tenant.
- **Fork-smoke test**: `bazelisk test //kernel/spec:fork_smoke`
  passes. A synthetic minimal tenant overlay still resolves.
- **SPEC-00351**: `bazelisk test //go/internal/spec:spec_test`
  passes. No kernel-side file references `tenant/defn` or
  `tenant/boot` in active code.

When a check from this list catches something, fix it in place
and add the fix to the review AIDR's "End-to-end probe" section.
When a check from this list is missing for a class of error you
saw during the work, that's a candidate for a new invariant under
3b.

## What this skill does NOT do

- **Does not fix findings.** Surfacing them is the job; fixing is
  `sp-bricks` (or an `sp-options` cycle).
- **Does not run interactively.** The two subagents see the diff
  once, in isolation, and return findings. No follow-up dialogue
  between reviewer and reviewee.
- **Does not gate merges.** This repo commits to main directly; the
  AIDR is documentation, not a gate. The user decides whether to
  push.
- **Does not block on style.** Style is `mise run check` (fmt
  tests). Reviewers focus on correctness, design, and security.

## Why two subagents in parallel

- **Isolation.** Each reviewer should think independently. Combining
  them produces blended findings where each lens softens the other.
- **Different prompts.** Code review optimizes for correctness and
  design; security review optimizes for attack surface, secrets,
  privilege boundaries. Mixing dilutes both.
- **Parallelism is safe** -- they read the diff, they don't write.

## Cross-references

- `sp-options` -- where non-trivial findings go for redesign.
- `sp-bricks` -- where trivial findings go for in-place fixes.
- `prompts/code-reviewer.md` -- code review subagent template.
- `prompts/security-reviewer.md` -- security review subagent template.
