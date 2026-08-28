# Bishop: notes for formalizing

Not loaded with the skill. Read this before making structural changes to `SKILL.md`.

## Status

Experiment, created 2026-08-28. Counterpart to `tars`, which inverts the roles: there the user writes the code and Claude navigates. Bishop is the lever for days when that is not sustainable.

## Hypothesis under test

The user reads every diff regardless, because they are accountable for what ships. So this mode cannot reduce review volume, only change its shape. The claim being tested is that the same volume is less draining when it arrives as small increments with the approach already agreed, than as one large finished diff.

Three plausible mechanisms, worth distinguishing if the result is positive:

- Sustained attention in one sitting versus spread across the work.
- Arriving at a diff already knowing its intent, rather than reconstructing intent from finished code.
- Sunk cost. A large finished diff creates pressure to accept it; small increments remove that pressure.

## Compound treatment

A positive result will not isolate batch size. This mode also supplies the approach agreement, which the user's previous full-delegation workflow did not have. If it feels better, that could be either ingredient. Do not conclude "batch size was the answer" without separating them.

## Knobs to tune

- **Batch size.** Currently one logical change with a single purpose, sized by appetite for review rather than by lines. If batches feel too small, the unit is probably too fine rather than the count too high.
- **Build cadence.** Currently build after each batch where incremental builds exist, full tests at slice close.
- **Feedback model.** Currently a stop-and-wait after each batch. Alternatives worth trying: a batch queue the user reviews at their own pace, or review-after-N.

## Criterion for keeping it

After several real sessions: less drained than a comparable delegation session, and nothing shipped that they would have caught by writing it themselves. Without a verdict this becomes a habit by default or gets dropped without anyone deciding.

## If it is kept

Consider whether it should merge into `tars` rather than stand alone. It duplicates the approach agreement, the disagreement rules, and the verification sweep. Merging is easy later; splitting is not, which is why it started separate. It was also kept separate so that a failed experiment could be deleted outright without editing a file that works.
