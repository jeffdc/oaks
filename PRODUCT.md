# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primary: oak identifiers, mostly iNaturalist identifiers trying to put a name on a tree or a hybrid. They use the site in three situations, all real:

- At a desk, with an iNat observation open in another tab, working through photos someone else took.
- In the field on a phone, standing under a tree checking buds, leaves and bark, possibly with poor signal.
- Studying a group (for example the red oaks) to get better at it, not working on a specific tree.

Second: botanists and researchers who need taxonomy, accepted names, synonyms, sources and citations they can rely on.

Editor: Jeff Clark is the only editor, now and for the next couple of years. He is also the site's author and is writing a book (a field guide to oaks) from the same material.

## Product Purpose

The Oak Compendium is a database and reference for oaks (Quercus), their varieties and their hybrids, aimed at the hardest part of oaks: getting a tree to species. The site's own stated goal is "the ultimate guide to oak identification".

It holds all of Jeff's oak data and some of his prose. The book is that prose plus more. Success means an identifier can tell what a tree is and why, a researcher can trace any claim to its source, and Jeff can maintain everything himself without hand-run SQL.

## Positioning

One field identifier's tested knowledge (5+ years, about 29,000 iNaturalist oak identifications) on how to tell oaks and their hybrids apart, with every claim traceable to his own observations or to cited literature. Oaks of the World, POWO and FNA describe taxa; the Compendium is built around telling them apart, hybrids included, in one expert's own words.

## Operating Context

- iNaturalist is the taxonomic backbone. Departures from iNat are Jeff's own sourced decisions.
- Scope: North America first for structured traits and identification. The rest of the world's oaks stay a reference catalog until later.
- Jeff's facts and prose lead. Other sources (Oaks of the World, Sibley, FNA, the literature in his research workbook) back them, and disagreements between sources are surfaced for him, not hidden.
- Two iNat workflows feed the database:
  - ID mode: pull in an observation, select the features that match (using the ID tool as needed), and produce a comment, at first a list of matching features with a link back to the taxon on the Compendium, which Jeff pastes into iNat with his ID. Bringing the comment back into the database is optional.
  - Capture mode: import a single comment Jeff wrote or found, or an exemplary observation. An imported observation can be a photo example on a taxon page, evidence for a fact, material for prose, and an illustration of a trait value.
- Agents run in Claude Code outside the app: they read the API and submit packages through one audited import path. The app itself makes no LLM calls.

## Capabilities and Constraints

- Phoenix LiveView on SQLite (Fly.io, Litestream). Staying on SQLite was confirmed in planning; gallformers' design is copied, not its Postgres-bound code.
- Public JSON API is read-only. All writes are Jeff's, through the app, audited with history and undo.
- Planned identification tools: a trait filter (multi-access key) and a hybrid helper. Look-alike comparison and written keys were not chosen as primary tools.
- Varieties and subspecies are real taxa with their own pages under their parent species.
- Hybrids include named nothospecies, formula names ("agrifolia × parvula") and intersectional hybrids with no section, each linked to its parents.
- Structured facts are created from Jeff's writing only by an agent proposing a fact with the verbatim quote that supports it; nothing counts until Jeff accepts it.
- Prose entries are separate from structured facts.
- Undecided: where the book is written and produced (Scrivener or the new tool); the wording of ID-mode comments beyond a feature list and link; whether ID-mode sessions are kept.

## Brand Commitments

- Name: the Oak Compendium (oakcompendium.org and oakcompendium.com). Sister project to Gallformers, by the same author.
- Voice: Oak Compendium prose is 100% Jeff's own words. Agents never write, paraphrase, summarize, condense or merge his prose; they only find and assemble his words verbatim, with sources, for him to edit.
- Copyright: facts can't be copyrighted, so anyone may use them. Jeff's prose and the structure of his entries are copyrighted (his prose goes into the book). Other authors' text stays as it is today: the Sibley entries are extracted facts, and the Oaks of the World text is fine to show; it must stay visibly distinct from Jeff's.

## Evidence on Hand

- 734 taxa (species, hybrids, varieties) with names, authors, synonyms and per-source descriptions; Oaks of the World, Sibley and a Botanical Gazette article as other sources.
- Jeff's verbatim material (local, gitignored, in `compendium-notes/`): 5,224 texts (iNat comments, ID remarks, manuscript paragraphs) linked to taxa; 29,411 oak identifications; his keep/drop sorting, contradiction resolutions and review notes; lobe and tooth counts per side for 46 species; a research workbook of literature values.
- 12 section and subsection pages and short Oak Compendium field text are live; the short text was agent-assembled and is to be reviewed piece by piece.
- Absent today, and not to be fabricated: photos, structured trait data beyond the lobe/tooth counts, range maps, testimonials or usage claims.

## Product Principles

- Jeff's words by construction: text shown as his is his exact wording, traceable to where he wrote it. Voice is preserved by the tooling, not by prompting.
- Every fact has a source a reader can see and follow.
- Identification first: every taxon answers "is it this, or that?", hybrids included.
- Jeff leads, sources back: conflicts between sources are shown and resolved by Jeff, not hidden behind tabs.
- Missing is empty: a one-off remark never becomes a general fact; when there is no general statement, the field stays empty.
