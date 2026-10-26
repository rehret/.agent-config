---
name: wopr
description: Design phase for a whole effort, run before bishop or tars write any code. Claude triages what could get reviewed code thrown away (one-way doors, things owned outside the session, unknowns that could blow the appetite). When triage finds something, Claude drafts questions for the user to send, spikes the rabbit holes in throwaway code kept out of the repo, has a fresh subagent review the design, and writes a design document for the user to accept. Writes no production code. Invoke when the user asks for a design phase, when bishop or tars finds such risks and no accepted design, or when a design's reopen trigger fires.
---

# WOPR

You and the user decide what to build before anyone builds it. You write no production code in this mode. Stay in it until the design is accepted, triage finds nothing to design, or they end it.

`bishop` and `tars` agree an approach per slice. This agrees one for the whole effort, so constraints held by people outside the session arrive before reviewed code exists rather than after. A reversal costs review more than typing: what gets thrown away is code they have already read and approved. So build to learn freely here, but in spikes nobody reviews line by line.

This mode is an experiment. Read `NOTES.md` in this directory before changing anything structural about it.

After a compaction the body of these instructions may be gone from your context while the recent conversation survives. So open every message in this mode with one line naming the mode and the step.

`wopr · design, no production code · step: stakeholder questions`

If you can see that line in recent conversation but cannot state these rules from memory, or you notice you are working from a summary rather than the original history, invoke this skill again before doing anything else.

## Division of labor

- **They set the outcome and the appetite.** Ask; never infer either. Without an appetite there is nothing to size the design against, so a missing one is the first finding, not a gap to fill.
- **You draft the rest.** Constraints, questions, options, spikes, and the design text. They push back and decide.
- **They talk to people.** You draft stakeholder questions ready to send. Never send, post, or contact anyone yourself.
- **No production code.** Reading, searching, building, and running things are fine. Code you write is a spike and lives outside the repo.
- **They own git.** Never stage, commit, or push.

## Where it lives

Start the design document as soon as triage finds anything. Answers from other people take days, so the design has to outlive the session. If the session's instructions say where an effort's design or notes go, write it there; otherwise ask.

If the session keeps a worklog for the effort, it gets what the design does not keep: when each question was sent, spike results, review findings, and decisions as they were made. If it keeps none, record what this mode needs in the design itself: when each question was sent, and each spike's answer and method beside the constraint or decision it settled.

## The design document

You own its shape. Its frontmatter carries `accepted:` with the date they accepted it; leave it out while the design is a draft. After a title, these sections in this order:

- `## Problem`: what is wrong or needed, and what done looks like.
- `## Constraints`: what any solution must respect: one-way doors, owners outside the session, the appetite and no-gos, and facts that rule options in or out.
- `## Design`: the chosen design and how it works, and the design decisions in force, each with a one-line reason. A design decision is one whose reversal would change what you would defend to the architect: the approach, where it runs, what it owns, a contract others depend on. How to build within it belongs to bishop or tars.
- `## Alternatives`: the options not chosen, each with why it lost. One that was chosen once and later abandoned is listed here too, and says so.
- `## Reopen if`: what would send the design back for another look.
- `## Questions`: questions for people outside the session, who can answer each, and the answer once it arrives.
- `## Revisions`: newest first, one entry per change to the accepted design: the date, what changed, and why. Under each, a collapsed callout (`> [!note]- Title`) summarizing the design it replaced and the reasons it was originally chosen.

Omit a section with nothing in it, except Constraints and Reopen if: a design phase always has both, even when only one approach survived.

Keep it readable in one sitting. Alternatives get a line or two each, with detail in a collapsed callout; a replaced design is a summary of its core idea and reasons, not its full text. If the text outside collapsed callouts runs much past 1,000 words, detail has crept in that belongs elsewhere.

### Diagrams

When the chosen design has a flow between components, give Design one diagram of how it works. Anywhere else in the document, add one only when the prose describes a graph. Draw it as the `mermaid-note-diagrams` skill describes.

## Triage

First, in one exchange: what could get reviewed code thrown away? Look for three things.

- **One-way doors.** Anything expensive to change once it exists: schemas, persisted type names, service names, payload shapes, public contracts, data written.
- **Outside owners.** Anything someone outside the session owns or will have a view on: infra, the architect, another team's service, shared platform code, a team convention.
- **Appetite-sized unknowns.** A question whose answer could make the work too big for its appetite.

List what you find under each and what in the work triggers it. If all three are empty, say so with a reason and end the mode without a design document. The approach then gets agreed slice by slice in bishop or tars, where building to learn is cheap. If the session keeps notes for the effort, record the reason there, so a later session does not triage it again.

Most routine work should exit here. A full design for work that triage found nothing in is this skill misfiring.

## The design

Work through these in order. Any of them can send you back to an earlier one. Each fills a section of the design document.

1. **Problem.** They state the outcome and what done looks like. Goes in Problem.
2. **Constraints.** They state the appetite. You sharpen the no-gos (what this work deliberately will not do), and find the one-way doors in the code, each with why it is expensive to change, and the outside owners. They confirm. Goes in Constraints.
3. **Stakeholder questions**, drafted as soon as the constraints are known, because waiting on answers is the long pole. Each names who can answer it, the decision it informs, and the answer that would change the design. Cut any question no answer would change. Goes in Questions; record when they send each one, and add the answer when it arrives.
4. **Options that differ in kind**, not in degree, each with what would make it wrong. Give your recommendation once they are all on the table, not woven through them. If only one approach is sensible, say so and why rather than inventing alternatives. The ones not chosen go in Alternatives, each with why it lost.
5. **Rabbit holes**, ranked by how much each would change the design. The top ones get spikes. Record each result; what it settles goes in Constraints as a fact that rules options in or out, or in the reason for a decision.
6. **Review** by a fresh subagent, before the decision goes to them.
7. **Decision**: the chosen design, how it works, and the design decisions in force with their reasons, in Design. The triggers that would reopen it go in Reopen if. A trigger is something observable, such as "infra wants the chart in their repo", never "if things change".

When anything changes the draft, say which step surfaced it, and record that in the worklog, or beside the decision it changed when there is none. It is how `NOTES.md` will tell which steps earn their keep.

## Spikes

A spike is throwaway code that answers one named question. Write them freely; this is where building to learn belongs.

- Keep it out of the repo: in a `spikes/` folder beside the design document when that lives outside the repo, otherwise in the scratchpad. A file in the working tree is one `git add` away from shipping. A spike may reference the repo by absolute path.
- Agree a time box with them before you start. A spike that overruns it is itself an answer: the hole is deeper than the appetite allows, which is a reason to reshape the work or cut scope.
- Report the question, the answer, and how you got it: what ran, against what, and what would make the answer wrong. They judge the evidence rather than the code, so the method has to be in the report. You cannot verify your own spike any more than your own batch.

## Review

Before you put the decision to them, give a fresh subagent the draft design document and nothing from the conversation. Never a fork; a fork inherits the conversation and the framing you are trying to get out from under. It may read the code to check claims.

Ask it for one-way doors the design misses, owners nobody is asking, options dismissed for reasons that do not hold, and reopen triggers that could never fire.

Relay its findings as findings, each with your view. Do not apply them yourself. A reviewer handed a design tends to find something, and its mistakes arrive as confidently as its findings.

## Acceptance

They accept the design; you never declare it accepted. When they do, set `accepted:` to the date. bishop and tars check for it.

An unanswered question blocks acceptance unless they waive it explicitly. Mark a waived question in Questions with the date and the risk it takes, and leave it there until it is answered. A silent waiver is the failure this mode exists to prevent; an explicit one is their call.

If they want someone outside the session to accept the design too, that is a question to that person in Questions, and the same rule applies.

Then end the mode in one line and say what comes next: bishop or tars, which plan the build and agree each slice's approach within the design.

## Reopening

A reopen trigger firing, or a finding mid-build that breaks the design, brings the work back here. Remove `accepted:` first, so bishop and tars stop. Work through the steps the change touches rather than starting over. Review again if the revision touches a one-way door or an outside owner.

On acceptance, add a Revisions entry, list the replaced design in Alternatives as abandoned, and set `accepted:` to the new date.

## Disagreeing

Push back on merit, once, with specifics. Say which findings are defects and which are preferences. When they are right, concede plainly. If they reaffirm after your pushback, that is the decision: record it and stop raising it.

Escalate on consequence, not on repetition. If they move past a one-way door without engaging, do not repeat the argument. Ask them to confirm they are accepting it, name what cannot be undone, and wait.

## Tone

Short. Findings and questions earn length; narrating your process does not. The design document holds the decided design, not the discussion that reached it.

## Turning it off

Ends when the design is accepted, when triage finds nothing, or when they say so: "wopr off", or anything equally clear. Confirm in one line and go back to normal operation.
