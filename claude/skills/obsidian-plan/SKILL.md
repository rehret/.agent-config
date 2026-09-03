---
name: obsidian-plan
description: Conventions for the per-project Obsidian plan note at $PLAN_NOTES/Projects/<TICKET>/Plan.md - path and ticket resolution, frontmatter, what counts as a step, and the altitude to write at. Invoke when creating or updating a plan note, when a plan is first approved (e.g. on exiting plan mode), or when a plan materially changes. Plan notes are off unless PLAN_NOTES names an existing vault directory.
---

# Obsidian plan note

Maintain a higher-level, self-sufficient plan note per project. Create it when a plan is first
approved.

## Per-machine gate

Plan notes are opt-in per machine and OFF by default. The `PLAN_NOTES` environment variable holds
the Obsidian vault root; a machine opts in by setting it in `~/.claude/settings.json`, which no repo
tracks:

```json
{ "env": { "PLAN_NOTES": "/path/to/vault" } }
```

The `SessionStart` hook in `claude/plan-notes-policy.sh` reports the policy at session start, so
normally you already know the answer. If you do not, check `PLAN_NOTES` before anything else and
treat unset, empty, or not-an-existing-directory as OFF: skip silently and do not mention it. Never
create the vault root yourself. Ticket folders under `$PLAN_NOTES/Projects/` are yours to create;
the vault root is not, because its absence is what signals that this machine does not keep notes.

## Path and ticket

- Path: `$PLAN_NOTES/Projects/<TICKET>/Plan.md` (e.g. `$PLAN_NOTES/Projects/ABC-123/Plan.md`). The file is
  always named `Plan.md`. Create the ticket folder if it doesn't exist. If `Plan.md` already exists
  for the ticket, update it in place, never create a second file.
- Determine the ticket number from the git branch name (e.g. `ABC-123`, `XYZ-456`). If the branch
  doesn't reveal it, ask in a single combined question whether the plan should be saved to Obsidian
  and, if so, the ticket number. There is usually one. If there is no ticket, ask for (or propose) a
  short descriptive name to use in place of `<TICKET>` for the folder name.

## Frontmatter

Begin the note with YAML frontmatter: `ticket` (omit if none), `repo`, `date`, and
`tags: [plan, <project tag>]`. No `branch` field; branches are named after the ticket. Write tags
without the leading `#` (e.g. `projects/some-migration`). Set `date` to today on creation and bump
it to today whenever the note is materially revised.

The project tag is decoupled from the ticket number (e.g. `#projects/some-migration`). Check the
project's memory for a recorded tag first; only ask if none is recorded, and when told a tag, record
it in that project's memory so you don't ask again.

## What counts as a step

When work is decomposed into tasks or cards, the note tracks the phase or slice, not the individual
task. A task starting or finishing sits below the note's resolution, so on its own it is not a
reason to write; a phase finishing is. Regardless of phase boundaries, write immediately when scope
moves, the sequence changes, a decision is recorded, or a trap worth remembering surfaces.

Keep one line naming the phase in progress and the task in flight. It is cheap, and it is the only
record of where things stood if the session loses its context.

## Altitude

Higher-level, not a verbatim copy of your working notes. Write the decided plan, not intermediate
drafts, and keep it more concise than your internal version.

The note must still be self-sufficient: if someone asks about any item the plan covers (a specific
project, file, or step), it should be answerable from the note alone without prompting Claude. Keep
the body scannable at summary level, but put complete enumerations (full project lists, affected
files, version specifics) in collapsed Obsidian callouts (`> [!note]- Title`) or an appendix rather
than condensing them to counts.
