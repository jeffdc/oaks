# ID tool

Phase 11 of the [Facts expansion](README.md). The trait filter, hybrid helper and ID mode from the prototypes. Needs Traits and fact review and the site shell.

## Done when

- The trait filter and hybrid helper work on real North American facts with range overlap and hedging.
- Jeff can run an observation through ID mode and copy a comment.

## Design input

`design/prototype/id-filter.html`, `id-hybrid.html`, `id-mode.html`; the ID tool brief in `.impeccable/surfaces/design-prototype-id-filter-html.md` (Jeff's matching rules: range overlap, hedging, nothing removed, no eastern bias); DESIGN.md, ID Tool Workbench. Large UI work: the full Impeccable process, including its finish review.

## Known so far

1. **Matching engine.** Range overlap, multi-value hedging, no data is neutral, three result groups, "check next".
2. **Trait filter.** Prototype `id-filter`.
3. **Hybrid helper.** Prototype `id-hybrid`.
4. **ID mode.** Prototype `id-mode`: load an iNat observation, tick features, and copy a comment that is a feature list plus the Compendium link. No saved sessions to begin with (Jeff). The Add photos dialog's observation loading (species photos plan) is the starting point for loading an observation.

## Held for this phase

- The This, or That direction from the home page round (`design/prototype/id-intro-this-or-that.html`: the site's question as a centred title over a real look-alike pair compared trait by trait, with an ID tip) as the ID tool's intro page (Jeff, 2026-11-21).
- A second, phone-specific view. Jeff: "we will almost certainly in the long run need a 2nd view for mobile, but we can hold on that for now." The Workbench prototype only stacks its panes on phones.

## To work out

- Whether the intro page and the phone view come in this phase or later.
