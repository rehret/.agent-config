---
name: mermaid-note-diagrams
description: How to draw Mermaid diagrams in plan notes and design documents, the working notes Claude keeps with the user, plus a script to preview them before writing. Not for diagrams meant for other people, such as READMEs, PR descriptions, or published docs, which have other constraints. Invoke before drawing a diagram into a plan note or design document.
---

# Mermaid note diagrams

How to draw a Mermaid diagram in a plan note or a design document: working notes for the user and Claude, read in Obsidian or on GitHub. Whether a document gets a diagram, and where, is up to the instructions that own the document; this covers how to draw one.

These rules are for those notes only. A diagram for other people, in a README, a PR description, or published docs, has a different audience and different constraints. Do not apply these there.

## When a diagram earns its place

Only when the prose describes a graph: dependencies, a flow across components, a state machine, an order that is not a straight line. Never for a plain list or a linear run of steps.

The diagram supports the prose and never replaces it. The prose must still stand on its own, and the two must agree, so put diagrams where the content is stable: one that has to be redrawn on every update drifts from the prose beside it.

## Drawing it

Write it in a fenced `mermaid` block. Mermaid places the nodes of a flowchart or state diagram itself, so you influence the layout but do not control it.

- **Pick the type for its layout.** A sequence diagram's layout is fixed, so prefer it for a flow across components. For states or dependencies, use a top-to-bottom flowchart rather than a state diagram, which gives no control over layout.
- **Keep labels short.** Edge labels get a few words; long ones cover edges and push nodes apart. The detail goes in the prose.
- **Keep it small:** under about a dozen nodes, labeled with the names the note uses.
- **Keep arrows back to earlier nodes few.** They cause most of the crossings.
- **Avoid left-to-right layouts with more than about four nodes in a row.** The renderer shrinks a wide diagram to the note's width, and the text becomes unreadable.
- **No styling or colors.** The renderer's theme handles light and dark.
- **Diagrams do not count toward a note's word guideline.**

## Checking the render

A diagram that parses can still be a tangle, and you cannot see the renderer. Before writing a diagram into a note, render it and look at it whenever a browser is available.

1. Run `render-preview.sh` from this skill's directory with the files holding the diagrams: notes, or `.mmd` drafts in the scratchpad. It finds the Mermaid version Obsidian bundles, writes a dark preview page at about a note's width, and prints the page's path. Pass `-o <dir>` to choose the directory, such as the scratchpad.
2. Serve that directory over local HTTP, for example `python3 -m http.server 8765 --bind 127.0.0.1 --directory <dir>`. Browser tools will not act on a page opened from disk.
3. Open the page and confirm every diagram rendered: `document.body.dataset.rendered` is `yes` and no element carries `data-error`. Then look at a screenshot, fix what is tangled, and render again.

Stop the server when you are done.
