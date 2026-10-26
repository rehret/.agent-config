# WOPR: notes for formalizing

Not loaded with the skill. Read this before making structural changes to `SKILL.md`.

## Status

Experiment, created 2026-10-26. Runs before `bishop` or `tars`, both of which agree an approach per slice; this agrees one per effort. Hooked into both under "Agreeing the approach". Owns the design document: its sections, acceptance marker, and revisions. Neither this skill nor `obsidian-plan` depends on the other, because plan notes can be switched off per machine. When they are on, the session's instructions put the document in `Design.md`, and `obsidian-plan` leaves its structure alone.

## Why it exists

A review of recent efforts found several partly built, then reversed. CORE-641's write-time enrichment was committed in bishop batches (phases 2 and 3) before the direction changed to background enrichment in AuditLog. CORE-694's chart ownership and autoscaling changed after infra weighed in once code existed. CORE-450's Service Bus emulator migration was abandoned as over appetite. CORE-467's outbox approach was parked.

bishop and tars already agree an approach, but per slice and inside an execution mode. Nothing gated the whole effort, so constraints held by people outside the session arrived late. In Shape Up terms, execution started while the work was still uphill.

CORE-641 had an options table and a recorded decision before phase 2. The reversal came mostly from a concern the architect raised once code existed; the user then re-weighed the options with that input rather than deferring to it. What the effort lacked was that input before reviewed code, and any stated condition for reopening the decision. So the gate matters more here than the options analysis, which tars already asks for.

## Hypothesis under test

A reversal costs review more than typing, because what gets thrown away is code the user has already read and approved. A gate that moves outside input and appetite-sized unknowns ahead of reviewed code reduces reversals after reviewed code, and costs routine work no more than the triage.

## Compound treatment

Beyond triage there are three ingredients: stakeholder questions, spikes, and the fresh-subagent review. A drop in reversals will not say which of them did the work. The skill asks for a record of the step that surfaced each change to a draft, in the worklog or beside the decision; read those before crediting any single ingredient, and before cutting one.

## Knobs to tune

- **Triage sources.** Currently three: one-way doors, outside owners, appetite-sized unknowns. A false negative points at the source that missed it. If the gate fires on routine work, "outside owners" is the likeliest to be too broad.
- **Spike time box.** Currently agreed per spike. If spikes routinely overrun, tie the box to a fraction of the appetite.
- **Review timing.** Currently once, before the decision. A second pass after stakeholder answers arrive is the obvious addition if answers keep reshaping accepted designs.
- **Acceptance.** Currently the user's call per effort, with unanswered questions blocking unless explicitly waived. If waivers become routine, the gate is not gating; the alternative is an outside reader for designs whose doors sit in shared platform or infra code.

## Criterion for keeping it

After several gated efforts:

- Fewer reversals after reviewed code than in the efforts above.
- No false negatives a reasonable triage would have caught: work triage sent straight to bishop or tars that later reversed.
- The skip path stays cheap: triage in one exchange, and most routine work exits there.
- Waivers stay the exception.

The aim is earlier, not omniscient. Some reversals will come from things nobody could have known to ask; judge it on the ones that could have been asked.

Without a verdict this becomes ceremony by default or gets dropped without anyone deciding.

## If it is kept

Kept separate so a failed experiment can be deleted outright: remove this folder and the hook line in each of bishop and tars. If bishop merges into tars, the hook lands in one place.
