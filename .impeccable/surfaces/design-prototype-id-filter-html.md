---
version: 1
slug: "design-prototype-id-filter-html"
primary_target: "design/prototype/id-filter.html"
related_targets: ["design/prototype/id-hybrid.html","design/prototype/id-mode.html"]
---

# ID tool

Mode: Operate. Prototype at design/prototype/id-*.html (static HTML) inside the world in DESIGN.md. Three parts in one Workbench structure: Trait filter, Hybrid helper, ID mode (tabs in the band).

## Audience and job

Identifiers at a desk beside an iNat tab, or on a phone under a tree, narrowing an oak (or hybrid) to the taxa it is consistent with, and seeing why. Jeff uses ID mode to work an iNat observation and copy a comment (feature list plus Compendium link) to paste with his ID.

## Rules (Jeff, 2026-11-21)

- Place first: state or province (and country) is the first input.
- Range overlap, not exact match: an observed range is consistent with a defined range when they overlap (seen 3–4 lobes per side is consistent with 3–5). Conflict only when they don't overlap.
- Uncertainty is allowed: any trait can take more than one value ("bristle or mucro, can't tell"). Nothing is ever struck out or hidden; candidates are grouped: consistent with everything, one conflict, more than one conflict. Each conflict is named with both values.
- No eastern-NA bias: the trait vocabulary must serve oaks anywhere (evergreen and deciduous, spines, mucros, stellate and other hairs, cup scales and tomentum, one- or two-year acorns, habit), with no red-oak/white-oak assumption. The prototype uses a California example on purpose; its trait values are illustrative.
- Where a taxon has no data for a trait, say so ("no data"); it neither counts for nor against.
- Descoped (Jeff, 2026-11-21, his words): "we will almost certainly in the long run need a 2nd view for mobile. but we can hold on that for now." The Workbench only stacks on phones; phone reach (results far down) is accepted until the phone view (mull idea c948).
- Workbench is a baseline: Jeff expects a lot of work later to make it good and useful.

## Direction contract

THESIS: Narrowing is a ranking with reasons, not elimination: every candidate stays, grouped by how consistent it is with what you saw, and every conflict is named in both values. It refuses the checkbox key that strikes taxa out on one doubtful trait.

OWN-WORLD: Inherited from DESIGN.md: ink masthead, the ochre band (here holding the tool's tabs and the place), ink on bright white, Archivo for the frame and Source Serif for names and Oak Compendium's own text, rules not boxes, agree/differs/open as drawn marks, tabular figures for counts.

STORY: The identifier sets the place, then adds what they can see, hedging where unsure; the middle pane re-groups the candidates live with each conflict spelled out; they open the best candidate on the right, compare it with the next, and (in ID mode) copy the comment.

FIRST VIEWPORT: Masthead; band with Trait filter / Hybrid helper / ID mode tabs and the place at the right. Three panes: left, place then traits by organ with range and multi-value controls; middle, a 'check next' line and candidates grouped Consistent / 1 conflict / 2+ conflicts, each row with per-trait marks and named conflicts; right, the selected taxon (photo, key traits, Compare, open page).

FORM: Workbench (kept by Jeff through a re-roll; first dealt as 1 of 6, then held as a pinned card). seed:d0e7fcaa9e64c9b3

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
