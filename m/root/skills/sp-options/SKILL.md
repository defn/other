---
name: sp-options
description: Supervisory layer: dialogue with user, write options/spec/plan as AIDR
---

# sp-options

## Overview

Interview the user about a problem, enumerate candidate solutions in
**brick terms** (which bricks change, which `defn stamp` commands
apply, which generators re-run), and capture the resolved direction
in an AIDR. The AIDR is a durable record of the dialogue, not
homework for the user -- assume the user will not read it. Drive
the conversation to a decision through questions, not by handing over
a document.

Implementation is a separate skill (`sp-bricks`); review is another
(`sp-review`). This skill never implements.

**Announce at start:** `Using sp-options to dialogue and write the next AIDR.`

## When to invoke

- User has a problem, idea, or design question that touches more than
  one file or one brick.
- User asks "what should we do about X?" or "how would we approach Y?"
- A `sp-review` AIDR surfaced a non-trivial finding worth a fresh
  options pass.

Do **not** invoke for trivial fixes (single-line bug, typo,
straightforward rename); skip directly to `sp-bricks`.

## Process

1. **Ask one question at a time.** Build understanding incrementally.
   Don't dump a checklist on the user; that produces shallow answers.

2. **Map the problem onto bricks.** For each option under
   consideration, identify:
   - Affected bricks (`grep` `kernel/catalog/bricks.cue` and the
     per-brick entries under `kernel/catalog/brick-*.cue`).
   - Required `defn stamp <kind> <path>` commands for any new bricks.
   - Generators that would re-run on `mise run hatch`.
   - Whether `kernel/spec/manual-files.cue` or
     `kernel/spec/convention-contracts.cue` need entries.
   - Existing AIDRs that bear on the decision (`ls m/aidr/`,
     `grep -l <topic> m/aidr/`).

3. **Enumerate 2-N options.** For each:
   - One-line summary.
   - Brick-level shape (which dirs change).
   - Tradeoffs in concrete terms (more bricks vs fewer; more catalog
     entries vs more hand-edits; affects kernel vs tenant).
   - Risks, reversibility, follow-up cost.
   - Which existing pattern it most resembles (e.g. "like the bot
     Midas", "like the aidr convention contract").

4. **Mint the AIDR.** Decide the type tag based on what the user
   asked for:
   - `spec` -- design / what to build.
   - `plan` -- how to build it (steps, ordering).
   - `options` -- side-by-side options, no recommendation yet.
   - `decision` -- a settled call (existing AIDR default).
   - `review` -- reserved for `sp-review`.

   Filename convention is `NNNNN-YYYY-MM-DD-<type>-<topic>.md`:

   ```
   mise run aidr -- <type> "Topic title"
   ```

   The `aidr` task takes the type as a mandatory first arg, validates
   it against the closed set above, auto-injects today's date into
   both the filename and the body `**Date**` line, and renders the H1
   as `<Type>: <Topic>`. No need to repeat the date or type in the
   title -- just the topic.

5. **Cross-reference precedents.** Inside the new AIDR, link related
   AIDRs by filename, e.g.
   `[AIDR-00071](00071-kernel-tenant-decoupling.md)`. Document the
   pattern you're mirroring (Midas, Pattern C, etc.).

6. **Consistency-review the user's choices before writing the AIDR.**
   When the dialogue resolves multiple decisions one-at-a-time, the
   user has been answering each in isolation -- they don't see the
   combined picture until later. Before drafting the AIDR body,
   audit the totality of choices for:

   - **Direct contradictions.** Choice X requires choice Y to be
     non-Z, but the user picked Z for Y.
   - **Weak synergy.** The combination is *consistent* but worse
     than alternative combinations the user wasn't shown -- e.g.
     X+Y is fine on its own but adds complexity that X+Y' would
     have avoided.
   - **Latent assumptions.** A choice was made on the assumption
     of another choice's value; if that other value flipped during
     the dialogue, the earlier choice may need revisiting.
   - **Volume vs. mechanism mismatch.** Choices about volume (e.g.
     "every brick" vs "hand-edited only") and choices about storage
     (e.g. "inline" vs "sharded files") interact -- "every" + "shard"
     creates 270 files; "every" + "inline" creates 270 inline blocks;
     "few" + "shard" creates a small handful of files.

   When the audit surfaces an issue, do NOT silently fix it. Surface
   it to the user with the specific tension and the candidate
   resolutions, and re-ask the affected question(s). Examples:

   > "Reviewing your four choices together: you picked (every-brick
   > coverage) + (sharded storage), which produces ~270 brick-io
   > shard files for what is mostly empty data. Either revisit Q1
   > (-> hand-edited only) or revisit Q2 (-> inline). Which?"

   > "Q3 (concrete paths) was picked under the Q1 (hand-edited
   > only) framing where path counts are small. Now that you've
   > switched Q1 to (every-brick), the concrete-paths choice
   > implies enumerating ~3000 paths. Want to revisit Q3 (-> globs)
   > or stay with concrete paths and accept the volume?"

   The audit is a single explicit checkpoint, not a continuous
   guard. It runs after the last design question and before the
   AIDR is minted. Skip it only when the dialogue had a single
   choice (no combination to audit).

7. **Reach equilibrium before stopping.** `git add` the new AIDR (the
   lattice/manifest gen walks git-tracked files only -- a fresh
   untracked AIDR is invisible to hatch), then run `mise run hatch`
   and `mise run check -- --ignore-unclean-workarea`. No need to ask
   the user first; this is the always-on equilibrium contract. Skip
   only if the workspace is intentionally mid-landing.

8. **Commit, check, push.** Once the workspace is at equilibrium,
   stage the AIDR plus any lattice/manifest regen, commit with a
   single descriptive message that names the AIDR number and the
   resolved trajectory, then `git push`. The pre-push hook re-runs
   `mise run check`; let it run. Do not skip hooks. If `check` is
   already green from step 7 the push completes quickly. If you
   later edit the AIDR in response to follow-up dialogue, repeat
   the equilibrium loop and push again -- AIDRs are chronological
   and edits land as new commits, never amended history.

9. **Keep interviewing -- do not hand the AIDR to the user to read.**
   After commit + push, resume the dialogue: ask the user about any
   remaining open questions, confirm the recommended option (or surface
   the trade-off if the user has not chosen yet), and probe for
   implementation-scope details that `sp-bricks` will need
   (sequencing, commit cadence, side-issues to defer). The AIDR is
   the durable record; the conversation is the decision-making loop.
   Only stop when the user explicitly closes the topic or asks you to
   hand off (e.g. "go implement", "/sp-bricks", "we're done"). Do not
   start implementing -- that is `sp-bricks`'s job.

## What this skill does NOT do

- Does not write code or run `defn stamp` -- that is `sp-bricks`.
- Does not run code or security review -- that is `sp-review`.
- Does not dispatch subagents. The dialogue is between you and the
  user directly. Round-trips for "let me check with another agent"
  cost time and rarely improve the AIDR.
- Does not invent paths, files, or generator behavior. If you do not
  know what a brick contains, read it before claiming what changes.
  Verify-before-recommend.

## Iteration

If the user asks follow-up questions after the AIDR is written:

- Small clarifications: answer in conversation; the user updates the
  AIDR if they want it captured.
- Substantive new options or pivots: mint a follow-up AIDR
  (`<NNNNN+1>-YYYY-MM-DD-options-<topic>-followup.md`) that
  references the original. AIDRs are chronological and immutable;
  appending an addendum is the canonical move.

## Output shape (suggested AIDR sections)

The default `mise run aidr` template emits Context / Decision /
Implementation. For an `options`-type AIDR, replace the body with:

```markdown
# AIDR-NNNNN: Options: <Topic>

**Date**: YYYY-MM-DD

## Context

What problem is this addressing. What constraints. Which bricks.

## Options

### Option A: <name>

- Brick-level shape: ...
- Tradeoffs: ...
- Risks / reversibility: ...
- Resembles: <existing pattern or AIDR>

### Option B: <name>

...

## Open questions

Things the user needs to decide or clarify before any option is
actionable.

## References

- [AIDR-NNNNN](NNNNN-...md) -- precedent
- `kernel/catalog/bricks.cue` -- affected bricks
```

For `spec` / `plan` / `decision` types, swap the body sections
(Spec / Requirements; Plan / Steps; Decision / Rationale) but keep
the Context, Open questions, and References frame.

## Cross-references

- `sp-bricks` -- the implementation layer once an option is chosen.
- `sp-review` -- runs at fixed point after `sp-bricks` finishes.
