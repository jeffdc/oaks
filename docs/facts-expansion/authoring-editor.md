# Authoring editor

Phase 9 of the [Facts expansion](README.md). Jeff writes structured entries from his material. Needs Taxonomy and Material and observations.

## Done when

- Jeff can open a taxon, see pre-existing text marked by provenance, insert his material verbatim, write, mark sections written and publish them (prototype `ed-entry`).
- Nothing agent-written can publish as his, and a test shows the import endpoint refuses entry text.

## Design input

`design/prototype/ed-entry.html`, `ed-facts.html`, `ed-conflicts.html` and the editor brief in `.impeccable/surfaces/design-prototype-ed-entry-html.md`; DESIGN.md, Authoring Editor. Large UI work: the full Impeccable process, including its finish review.

## Known so far

1. **Entry structure.** The shared section list (key sentence, account, historical context, more), each with its purpose; editable by Jeff.
2. **Entries, versions and provenance.** Sections with immutable versions and provenance spans: inserted from material (with the material span), typed by Jeff, or agent wording. Only Jeff's session writes entry text; the import endpoint rejects it.
3. **Editor screen.** Prototype `ed-entry`: section blocks and their states, key-sentence checks and the fragment preview, the material column with insert and set aside, versions, Mark written, keyboard.
4. **Load the live short text for review.** The 2026-11-20 short Oak Compendium text loads as agent wording, flagged for review; Jeff's × *fontana* edit (Laughlin's description) is kept as his.
5. **Publish and preview.** Only written sections publish; preview as the taxon page.
6. **Section across taxa.** Work one section for many taxa, for consistency.

## To work out

- **Entry sections.** The full list after key sentence, account and historical context. Default: those three for now, more added as Jeff needs them.
- **Publishing.** Does marking a section written publish it, or do sections wait for a Publish? Default: marking it written publishes it.
- Today's Oak Compendium text sits in `species_sources` rows by field (leaves, bark, …). How those fields map onto entry sections when step 4 loads them.
