---
name: obsidian-plan
description: Conventions for the plan note at $OBSIDIAN_PLAN_VAULT/$OBSIDIAN_PLAN_DIR/<TICKET>/Plan.md or .../<Project>/Plan.md - path and ticket resolution, frontmatter, what counts as a step, and the altitude to write at. Invoke when creating or updating a plan note, when a plan is first approved (e.g. on exiting plan mode), or when a plan materially changes. Plan notes are off unless OBSIDIAN_PLAN_VAULT names an existing directory.
---

# Plan note

Maintain a higher-level, self-sufficient plan note per effort. Create it when a plan is first
approved.

## Per-machine gate

Plan notes are opt-in per machine and OFF by default. Two environment variables configure them, set
in `~/.claude/settings.json`, which no repo tracks:

```json
{ "env": { "OBSIDIAN_PLAN_VAULT": "/path/to/vault", "OBSIDIAN_PLAN_DIR": "Projects" } }
```

- `OBSIDIAN_PLAN_VAULT` is the Obsidian vault root, and setting it to an existing directory is what
  opts the machine in.
- `OBSIDIAN_PLAN_DIR` is optional: the folder the note folders live in, relative to the vault root.
  It defaults to `Projects`, and `.` puts them at the vault root itself. It must stay inside the
  vault, so never absolute and never climbing out with `..`.

The `SessionStart` hook in `hooks/plan-notes-policy.sh` beside this file (or the `.ps1` twin on
Windows) reports the policy at session start, so normally you already know the answer. If you do
not, check both variables before anything else and treat an unset, empty, or not-an-existing
`OBSIDIAN_PLAN_VAULT` as OFF: skip silently and do not mention it. Never create the vault yourself,
because its absence is what signals that this machine does not keep notes. Everything under it,
`$OBSIDIAN_PLAN_DIR` included, is yours to create.

## Path and scope

A plan note covers one effort. Usually that is a single ticket; sometimes it is a project spanning
several. The folder name says which, and the file is always `Plan.md`. Writing `$BASE` for
`$OBSIDIAN_PLAN_VAULT/$OBSIDIAN_PLAN_DIR`:

- Single ticket: `$BASE/<TICKET>/Plan.md` (e.g. `.../Projects/ABC-123/Plan.md`).
- Multi-ticket project: `$BASE/<Project Name>/Plan.md`, with any per-ticket notes nested beneath it
  at `$BASE/<Project Name>/<TICKET>/Plan.md`.

For a multi-ticket project the project plan is the default home, and a nested ticket note is the
exception. Add one only when that ticket carries nuance worth tracking apart from the overall plan,
and keep the two cross-linked: the project plan links down to each ticket note that exists, each
ticket note links up to the project plan. Wikilinks resolve against the vault root, not `$BASE`, so
write them relative to the vault (e.g. `[[Projects/Some Project/ABC-123/Plan]]`).

Before creating any note, look for an existing one at either depth and update it in place rather
than creating a second:

```bash
find "$OBSIDIAN_PLAN_VAULT/${OBSIDIAN_PLAN_DIR:-Projects}" -type d -name '<TICKET>'
```

## Resolving ticket and scope

Determine the ticket number from the git branch name (e.g. `ABC-123`, `XYZ-456`).

When the approved plan visibly spans more than one ticket, ask a single combined question covering:
whether to save the plan note, the project folder name, and whether any ticket also needs its own
nested note. Do the same when the branch does not reveal a ticket, asking for the ticket number or,
if there is no ticket, a short descriptive folder name.

If a ticket already has a top-level note and later joins a project, ask before relocating it. Moving
the folder outside Obsidian does not update wikilinks, so after a move, find and fix references from
the vault root, which catches links from notes outside the plan tree:

```bash
grep -rl "\[\[<TICKET>" "$OBSIDIAN_PLAN_VAULT"
```

## Frontmatter

Begin the note with YAML frontmatter: the ticket, `repo`, `date`, and `tags: [plan, <project tag>]`.
A single-ticket or nested ticket note uses `ticket: ABC-123`; a project plan uses
`tickets: [ABC-123, ABC-124]`, listing the tickets it covers, and omits the field if none. No
`branch` field; branches are named after the ticket. Write tags without the leading `#` (e.g.
`projects/some-migration`). Set `date` to today on creation and bump it to today whenever the note
is materially revised.

The project tag is decoupled from the ticket number (e.g. `#projects/some-migration`) and is what
binds a project plan to its ticket notes, so they share it. Check the project's memory for a
recorded tag first; only ask if none is recorded, and when told a tag, record it in that project's
memory so you don't ask again.

## What counts as a step

When work is decomposed into tasks or cards, the note tracks the phase or slice, not the individual
task. A task starting or finishing sits below the note's resolution, so on its own it is not a
reason to write; a phase finishing is. Regardless of phase boundaries, write immediately when scope
moves, the sequence changes, a decision is recorded, or a trap worth remembering surfaces.

Keep one line naming the phase in progress and the task in flight. It is cheap, and it is the only
record of where things stood if the session loses its context.

A project plan tracks the phase or slice across its tickets, which may mean a whole ticket is one
line in it. Detail that would drag it below that resolution belongs in a nested ticket note.

## Altitude

Higher-level, not a verbatim copy of your working notes. Write the decided plan, not intermediate
drafts, and keep it more concise than your internal version.

The note must still be self-sufficient: if someone asks about any item the plan covers (a specific
project, file, or step), it should be answerable from the note alone without prompting Claude. Keep
the body scannable at summary level, but put complete enumerations (full project lists, affected
files, version specifics) in collapsed Obsidian callouts (`> [!note]- Title`) or an appendix rather
than condensing them to counts.

A project plan is self-sufficient on its own terms: answerable at the project's altitude without
opening the nested ticket notes.
