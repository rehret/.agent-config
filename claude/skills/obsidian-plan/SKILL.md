---
name: obsidian-plan
description: Conventions for the plan notes at $OBSIDIAN_PLAN_VAULT/$OBSIDIAN_PLAN_DIR/<TICKET>/ or .../<Project>/ - Design.md (the chosen design and why, when a design phase ran or the effort chose between approaches), Plan.md (how it is being built), and Status.md (where the work stands) for the user, and an append-only Worklog.md for Claude. Covers path and ticket resolution, frontmatter, what goes in which file, resuming from them, and splitting older single-file notes. Invoke before looking for, creating, or updating a plan note (including any check for an existing one at session start), when a design phase starts, when a plan is first approved (e.g. on exiting plan mode), or when a design or plan materially changes. Plan notes are off unless OBSIDIAN_PLAN_VAULT names an existing directory.
---

# Plan notes

Each effort gets a folder of notes:

- **`Design.md` is for the user: the design sketch.** The problem, the options, the design chosen,
  and why it won. It always describes the design being executed; when that changes, it says what
  changed and why. Only for efforts that went through a design phase or chose between approaches.
- **`Plan.md` is for the user: the plan for executing it.** The phases, their order, and the
  decisions made while building. It changes only when the plan does.
- **`Status.md` is for the user: where the work stands.** The current phase, each phase's state,
  what is next, and what will bite whoever does it. Rewritten in place as the work moves.
- **`Worklog.md` is for Claude.** An append-only, dated record of the work: batches, commits,
  verification, decisions as they were made. It lets a later session recover the detail, and it is
  where history goes so the other notes do not have to carry it.

Read them in that order: the design to recall what is being built and why, the plan for how, then
the status.

`Design.md` and `Worklog.md` are created when a design phase starts. `Plan.md` and `Status.md` are
created when a plan is first approved, along with `Worklog.md` if it does not exist yet. An effort
with no design phase starts at approval with those three.

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

A note folder covers one effort. Usually that is a single ticket; sometimes it is a project spanning
several. The folder name says which, and the files are always named `Design.md`, `Plan.md`,
`Status.md`, and `Worklog.md`. Writing `$BASE` for `$OBSIDIAN_PLAN_VAULT/$OBSIDIAN_PLAN_DIR`:

- Single ticket: `$BASE/<TICKET>/` (e.g. `.../Projects/ABC-123/Plan.md`).
- Multi-ticket project: `$BASE/<Project Name>/`, with any per-ticket notes nested beneath it at
  `$BASE/<Project Name>/<TICKET>/`.

For a multi-ticket project the project plan is the default home, and a nested ticket note is the
exception. Add one only when that ticket carries nuance worth tracking apart from the overall plan,
and keep the two cross-linked: the project plan links down to each ticket note that exists, each
ticket note links up to the project plan. Wikilinks resolve against the vault root, not `$BASE`, so
write them relative to the vault (e.g. `[[Projects/Some Project/ABC-123/Plan]]`).

Every folder with a `Plan.md` has its own `Status.md` and `Worklog.md`. A project's notes track the
project's level (a ticket starting or merging, a decision spanning tickets); task detail goes in the
ticket's.

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

Begin `Plan.md` with YAML frontmatter: the ticket, `repo`, `date`, and
`tags: [plan, <project tag>]`. A single-ticket or nested ticket note uses `ticket: ABC-123`; a
project plan uses `tickets: [ABC-123, ABC-124]`, listing the tickets it covers, and omits the field
if none. No `branch` field; branches are named after the ticket. Write tags without the leading `#`
(e.g. `projects/some-migration`). Set `date` to today on creation and bump it to today whenever the
plan is materially revised.

The other notes carry the same fields with their own tag in place of `plan`:

- `Design.md`: `design`, with `date` bumped on every revision. Keep any other fields the design
  document already carries, such as a record of its acceptance.
- `Status.md`: `status`, with `date` bumped on every update, so a reader can see how fresh it is.
- `Worklog.md`: `worklog`, and no `date`, since every entry carries its own.

The project tag is decoupled from the ticket number (e.g. `#projects/some-migration`) and is what
binds a project plan to its ticket notes, so they share it. The notes are its record, not memory.
Read it from the frontmatter of the project plan or of any note already carrying it; a project
may be tracked in a top-level ticket note rather than a project folder, so search the whole tree:

```bash
grep -rn --include=Plan.md '^tags:' "$OBSIDIAN_PLAN_VAULT/${OBSIDIAN_PLAN_DIR:-Projects}"
```

Ask only when no note carries the project's tag yet. The note you then write records it, so do not
also store tags or note paths in memory, where they go stale as notes move.

## Design.md

Only for an effort that went through a design phase or chose between approaches. Routine work has
none; its `Plan.md` states the problem in its Why section instead.

`Design.md` holds the effort's design document: the problem, the options, the design chosen and why
it won, and how it changed mid-build and why. Its sections and conventions belong to whatever
produced it, so leave its structure alone. This skill adds only the frontmatter fields above, a
`# <TICKET>: Design` heading if it has no title, and a link to the plan once it exists.

## Plan.md

After the frontmatter, a `# <TICKET>: <title>` heading and a line linking the other notes
(`Design: [[Projects/<...>/Design]] | Status: [[Projects/<...>/Status]] | Worklog: [[Projects/<...>/Worklog]]`,
leaving out the design when there is none), these sections in this order. Omit any with nothing in
it.

- `## Why` (only when there is no `Design.md`): the goal, and what done looks like.
- `## Tickets` (project plans only): one row per ticket with its scope, linking down to any nested
  note. No state; that is in `Status.md`.
- `## Phases`: how the work breaks down, what each phase achieves, the order, and why that order. No
  state, so a phase finishing does not touch this file. When the phases are not a straight line, add
  the dependency diagram described under Diagrams.
- `## Decisions`: decisions made while building, each with a one-line reason. Without a
  `Design.md`, this holds the approach too. A reversed decision is replaced by its successor; the
  story belongs in the worklog. Rejected alternatives worth remembering go in a collapsed callout.
- `## Open questions`: what is undecided about the build, with who can answer it.

`Plan.md` holds nothing about execution state: no phase states, branches, commits, or next actions.

### Altitude

Write the decided plan, at the altitude a reader needs in order to recall the effort and judge it.
The note must still be self-sufficient: if someone asks about any item the plan covers (a specific
project, file, or step), it should be answerable from the note alone without prompting Claude. Keep
the body scannable, but put complete enumerations (full project lists, affected files, version
specifics) in collapsed Obsidian callouts (`> [!note]- Title`) rather than condensing them to counts.

If the text outside collapsed callouts runs much past 1,000 words, history or execution detail has
probably crept in. Move it to the worklog or `Status.md`.

A project plan is self-sufficient on its own terms: answerable at the project's altitude without
opening the nested ticket notes.

## Status.md

After the frontmatter, a `# <TICKET>: Status` heading and a link back to the plan
(`Plan: [[Projects/<...>/Plan]]`), these sections in this order. Omit any with nothing in it, except
Now.

- `## Now`: at most three lines: the phase in progress, what blocks it, what comes next. Replace it
  on every update; never append to it. Appending is how a status line turns into a log.
- `## Phases`: each phase from the plan, by the plan's name for it, with its state and its branches
  and PRs. A project lists its tickets' states here.
- `## Next steps`: the concrete actions ahead.
- `## Traps`: what will bite whoever works on this next, when it outlives the task that found it.
- `## Working agreements`: how this effort is being worked where it departs from the defaults, such
  as the pairing mode, who names things, or whether Claude commits. A later session follows these.

Everything here describes the present, so check claims against the repo when rewriting rather than
copying them forward. A state carried over from an older version is how a note ends up saying that
something merged weeks ago is still waiting.

## Worklog.md

After the frontmatter, a link back to the plan, or to the design until the plan exists, then
entries, oldest first and newest at the bottom, each headed with its date and a short summary:

```markdown
## 2026-10-26: Slice 2, batch 3 committed
```

An entry records what happened: tasks, cards, or batches and their commit hashes; verification run
and its results; decisions, with who made them and when, quoting the user where the wording matters;
reversals and why; traps found. End it with what is in flight, if anything. That line is the only
record of where things stood if the session loses its context.

Append only. Never edit a past entry; correct one with a new entry that says what was wrong.

## What goes where

A decision belongs in `Design.md` if reversing it would change what you would defend to an architect:
the approach, where it runs, what it owns, a contract others depend on. A decision about how to
build within that approach belongs in `Plan.md`.

Write in the same turn as the event. When a turn touches more than one file, write the worklog entry
first, then the others in reading order.

| Event | `Design.md` | `Plan.md` | `Status.md` | `Worklog.md` |
|---|---|---|---|---|
| Task, card, or batch done; commit; test run | nothing | nothing | Next steps, if they moved | entry |
| Phase starts or finishes | nothing | nothing | Now and Phases | entry |
| Build decision made or reversed | nothing | Decisions | anything it changes | entry, with the reasoning |
| Design changed mid-build | the design, with what changed and why | Phases and Decisions it affects | anything it changes | entry, with the reasoning |
| Outside question answered | the design, if it records the question | nothing | nothing | entry |
| Phases added, dropped, or reordered | nothing | Phases | Phases and Next steps | entry |
| Trap found | nothing | nothing | Traps, if it outlives the task | entry |

A change to the phases or their order lands in `Plan.md` first; `Status.md` refers to phases only by
the plan's names for them.

A project plan tracks the phase or slice across its tickets, which may mean a whole ticket is one
line in it. Detail that would drag it below that resolution belongs in a nested ticket note.

## Resuming

Read `Design.md`, `Plan.md`, and `Status.md` in full, whichever exist. Then read `Worklog.md` from
the bottom up, as far as you need to know what was in flight, usually the last few entries. Search it
for specifics rather than reading it end to end.

## Parked work

Refer to parked work by branch name, or by stash commit and message. Never by stack position
(`stash@{1}`): positions shift whenever anything is stashed or dropped, so a note that says to pop
one will eventually apply the wrong work. Prefer a branch for anything parked longer than a session.

## Formatting

Do not hard-wrap prose. Write one physical line per paragraph, list item, and callout line; Obsidian
soft-wraps at the reader's configured width, and hard wraps render ragged. Tables, fenced code, and
frontmatter keep their own form.

When reflowing an existing note, a wrapped continuation that begins with `- ` becomes a new list
item once joined, silently splitting one bullet into two. Verify a reflow by comparing the word
stream before and after, not by eye.

## Diagrams

`Plan.md` gets a diagram when its phases are not a straight line: a flowchart of which phase depends
on which. Elsewhere in `Plan.md`, add one only when the prose describes a graph. `Status.md` and
`Worklog.md` get none: state changes on every update, and a copy of the plan's diagram would drift
from it. Draw diagrams as the `mermaid-note-diagrams` skill describes.

## Notes from before the split

Older efforts have a single `Plan.md` that mixes design, plan, status, and log. Split one when you
next touch it; do not sweep the vault unasked.

1. Create `Worklog.md`. Its first entry, dated today and titled `Pre-split plan archived`, holds the
   old `Plan.md` body verbatim: frontmatter dropped, and headings outside fenced code demoted two
   levels so they nest under the entry. Verify by comparing word streams with `#` marks stripped.
2. Write a fresh `Plan.md` and `Status.md` from the archived content, and a `Design.md` if the effort
   chose between approaches, checking each state claim against the repo before carrying it. The
   design records the problem, the options, the design chosen and why, and any mid-build change with
   its reasons. Carry over any acceptance the old note records.
