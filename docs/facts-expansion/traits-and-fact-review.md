# Traits and fact review

Phase 8 of the [Facts expansion](README.md). A global trait vocabulary, sourced trait facts, and Jeff's review screens. Needs Taxonomy and Material and observations.

## Done when

- Jeff has approved the vocabulary.
- Jeff's counts and other sources' values are loaded as facts.
- An agent can propose a fact with its quote through the import endpoint.
- Jeff can accept, edit or decline proposals and resolve conflicts in the editor frame (prototypes `ed-facts`, `ed-conflicts`).

## Design input

`design/prototype/ed-facts.html` and `ed-conflicts.html`; DESIGN.md, Authoring Editor. The review screens are Large UI work: the full Impeccable process.

## Known so far

1. **Trait vocabulary.** Organs, traits, kinds (categorical, range, count), units, values, source-term mappings. Seeded from the research workbook and the ID tool prototype's list; checked for eastern North American bias. Jeff approves it.
2. **Load measure and source facts.** Jeff's lobe and tooth counts as measure facts sourced to his counts; the research workbook's literature values as other sources' facts; `species_sources` text kept verbatim as source descriptions.
3. **Fact proposals through the import endpoint.** Agents propose facts, dry run first; they arrive as proposals for the review screen. Producer notes for agents, added to [docs/import.md](../import.md): facts from Jeff's materials carry the exact supporting sentence, never prose. Anecdotes from single observations are flagged, not promoted.
4. **Fact review screen.** Prototype `ed-facts`: accept, edit the value then accept, decline with a reason, undo, focus, keyboard.
5. **Conflict review screen.** Prototype `ed-conflicts`: values side by side, resolutions recorded with when, undo.

"Undo" in steps 4 and 5 reverses a review decision in the app. It is not an audit log, which was dropped.

## To work out

- Where the research workbook lives and what it holds, for steps 1 and 2.
- Whether the conflict records built in Sources and facts core need anything more for the screen.
