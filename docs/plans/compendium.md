The Oak Compendium rebuild, agreed with Jeff on 2026-11-21 after a planning and design session. A readable version of this plan is at https://claude.ai/code/artifact/d1136370-ece1-4986-8b46-1c6c5b436e88; it predates dropping the audit log and undo and the simpler import endpoint (both 2026-11-21), and this doc wins where they differ.

## Goals
- **Who it's for.** Oak identifiers first (mostly iNaturalist identifiers, at a desk beside an iNat tab or on a phone under a tree), botanists and researchers second. Jeff is the only editor.
- **What it is.** The reference for telling oaks and their hybrids apart: one field identifier's tested knowledge, every claim traceable to his observations or to cited literature. North America first; the rest of the world stays a reference catalog until later. iNaturalist is the taxonomic backbone.
- **Jeff's words.** Oak Compendium prose is 100% Jeff's. Agents never write, paraphrase, summarize or merge it. They find his material, assemble it verbatim with sources, and propose facts with the quote behind each. Nothing counts until Jeff accepts it.
- **Facts.** Every fact is tied to its source, the way gallformers' taxogall does it. Jeff's facts lead; other sources stand behind them; conflicts are surfaced for Jeff, not hidden.
- **No hand SQL.** Every change goes through the app or the one import endpoint (every import is dry-run first, and Jeff reads the dry-run report before it applies). Hand-run SQL over Fly is designed out. There is no audit log or undo (see the note under Architecture).
- **The look.** DESIGN.md and the prototypes in design/prototype/ are the reference for every page.

Done when:
- Taxa, names, hybrids, varieties and synonyms live in the new taxonomy model, linked to iNat.
- Jeff's material (comments, ID remarks, manuscript, review notes) is in the database, private, with sources.
- Facts, traits and conflicts are sourced and reviewable; Jeff's lead.
- Jeff writes and publishes structured entries in the in-site editor; nothing agent-written can publish as his.
- The public site runs on the new design: taxon pages, comparisons, hybrids, ID tool.
- Every data change goes through the app or the import endpoint after a dry run; no SQL over fly ssh.

## Settled with Jeff (do not reopen)
- Stay on SQLite. Copy gallformers' design and its pure modules (not its Carbonite audit log).
- No audit log and no undo for now (Jeff, 2026-11-21). Add them later only if a need appears.
- iNaturalist is the taxonomic backbone; departures are Jeff's sourced decisions.
- North America first for traits and the ID tool.
- Varieties and subspecies are taxa with their own pages under their species.
- Agents run in Claude Code outside the app and submit bulk changes through one import endpoint, always as a dry run first; the app makes no LLM calls.
- Facts from Jeff's writing: an agent proposes, with the verbatim quote; Jeff accepts.
- The editor lives in the site, admin-only. Reviewing the live agent-assembled text is the same screen as writing.
- Entries follow one structure: key sentence (the fragment on the taxon page), account, historical context, more to come.
- No more bulk exports from iNat. ID mode and capture mode tie individual observations to the database.
- One template for every taxon page; sections show by data, not by whether Jeff has covered the taxon.
- Comparisons are a mode of the taxon page at ?vs=, deep-linkable; the write-up reader is at ?read=.
- Copyright: facts can't be copyrighted; anyone may use them. Jeff's prose and the entry structure are copyrighted (Jeff, plan question 6).
- Other authors' text stays as it is today: the Sibley entries are extracted facts, and the Oaks of the World text is fine to show (Jeff, question 5).
- Any source can be a source of range data (Jeff, question 4).
- ID mode starts as a feature list plus a link; no saved sessions to begin with (Jeff, question 8).
- The login session starts with an architecture and technology discussion with Jeff before any code (Jeff, question 1).
- The book is out of scope for now; the model keeps both options open (Jeff, question 3).
- No API key rotation for now: low risk (Jeff, question 9). Search bug 4742 waits (Jeff, question 10).

## Design references
- PRODUCT.md: product truth (users, positioning, brand commitments, principles).
- DESIGN.md (and .impeccable/design.json): the visual world and every settled component.
- design/prototype/: the three prototype pages (taxon page set, ID tool, editor). They are the reference for UI phases; their data is illustrative.
- .impeccable/surfaces/: the surface briefs with Jeff's rules for each page (one-template rule, range overlap, no eastern bias, structured entries, key sentence as fragment).
- All UI work uses the impeccable skill (Jeff's standing instruction).

## Architecture
- **Contexts.** Business logic splits into contexts that own their tables and talk through published read models, as in gallformers: Taxa, Sources (works, materials, observations), Facts, Traits, Entries, Import. Nothing reads another context's tables directly.
- **Taxa.** taxa (rank: genus, subgenus, section, subsection, complex, species, subspecies, variety, form, nothospecies, formula hybrid), taxon_names (accepted, synonym, misapplied; authorship), a closure table for ancestry, and the iNat taxon id. Named hybrids and formula hybrids are taxa; their parentage is a sourced fact. An intersectional hybrid sits at the lowest rank both parents share. Port gallformers' Taxa.Ancestry, tree validator and NameNormalizer.
- **Sources and material.** sources are works (books, articles, websites, iNaturalist, Jeff's own field notes). materials are Jeff's verbatim texts (iNat comments and ID remarks, manuscript paragraphs, review notes), each with date, URL, authorship (Jeff, cited, not Jeff), taxon links, a set-aside flag and a duplicate group. Materials are private and never in the public API. observations are iNat observations with photos, licence and roles: exemplar photo, evidence, material, trait illustration.
- **Facts.** facts (kind, slot, standing), attributions (fact x source: stance, partial date, value as written), evidence (a material span, a document quote with page, or an observation), and typed detail tables: trait facts, measure facts (min, usual range, max, unit), range facts (place, native or introduced), parentage facts. Standing differs from gallformers' newest-wins: Jeff's Oak Compendium fact leads its slot; other sources sit behind it; values that disagree in a slot raise a conflict for Jeff (mine stands, update mine, not a conflict: variation). Measures compare by range overlap.
- **Traits.** A global trait vocabulary (organ, kind: categorical, range or count, unit), values, and source-term mappings like gallformers' trait_term_mappings. No eastern North American or red/white oak assumptions. Jeff approves the vocabulary.
- **Entries.** entry_structure (the shared sections and their purpose), entries, sections, immutable section versions, and provenance spans inside each version: inserted from material (with the material span), typed by Jeff, or agent wording (pre-existing). Entry text can only be written by Jeff's own session in the editor; the import path rejects it. Only sections Jeff marks written publish.
- **No audit log, no undo (Jeff, 2026-11-21).** An earlier draft of this plan had an audit log (actor context, triggers, before and after images) and transaction undo. That over-read Jeff's point, which was only that changes must not be pushed to SQLite by hand-run SQL scripts. Both were dropped (items d635, 24eb). If you find a leftover mention of auditing, undo through an audit log, or "audited" writes anywhere in this plan, its items or the code, ignore it: don't implement it and don't raise it as a question. ("attributions" in Facts means a fact's sources, which stays; the audit-2026-11 plan is an unrelated codebase review.)
- **Import.** One private endpoint for every bulk change (Jeff, 2026-11-21, decision e661): agents in Claude Code, scripts and data loads all send JSON shaped like the data model (one key per table, field names as in the Ecto schemas, local refs between records in one body) with a scoped token. Each record goes through its Ecto changeset, and the whole body applies in one transaction or not at all, with errors reported per record. A dry run validates and reports what would be created or changed without writing, and returns a token tied to the exact body; the real call is refused without a matching token, so every import is dry-run first (decision 62ae). Re-sending an applied import is a no-op. Each model adds its tables to the endpoint as it lands. There is no JSON Schema contract, Python validator, staging or diff screen, and no import undo: an earlier draft copied gallformers' package contract, which was more than needed (item e773, dropped; the work is item f8f5).
- **Auth.** Replace the shared API key in localStorage with a real single-user login (phx.gen.auth) for Jeff, and scoped API tokens for agents (read private material, submit imports). Public reads stay public.
- **API.** The public read-only v1 keeps working through an adapter until the site moves. A v2 serves the new model (taxa, names, published entry sections, facts with sources) to the public. A private API serves agents.
- **Gallformers.** Copy the proven pure modules now (standing rules, partial dates, quote locating, name normalizing, ancestry), but not its import contract (see Import). The fragment-and-reader component is the first candidate to share as code; decide on a shared package once both apps settle.

## Moving today's data
- species rows become taxa and names: hybrid names parsed (×, formula, misspellings), two-word infraspecific names become child taxa with ranks, autonyms handled, synonyms become names, parent1/parent2 become parentage facts sourced as legacy data.
- species_sources free text stays verbatim as each source's description, shown behind Jeff's facts; nothing is promoted to a field.
- The 2026-11-20 short Oak Compendium text loads into the editor as agent wording, flagged for review. Jeff's × fontana edit (Laughlin's description) is kept as his.
- Lobe and tooth counts become measure facts sourced to Jeff's counts; the research workbook's literature values become other sources' facts.
- compendium-notes material loads as materials: snippets.jsonl, manuscript paragraphs with authorship, review notes; Jeff's keep/drop sorting maps to set-aside; other people's comments are excluded. Jeff checks a sample before it applies.
- Every load goes through the import endpoint: dry run first, and Jeff reads the dry-run report before it applies. Schema changes are migrations; data changes are imports.

## Why this order
Foundations first: nothing else should write data until Jeff logs in properly and bulk changes come through the import endpoint. Sources and facts come before taxonomy because hybrid parentage, ranges and traits are sourced facts. Material can load in parallel with taxonomy. Traits and fact review need both taxa and material; so does the editor. The site shell can start right after Foundations; the public taxon pages need taxa, facts, entries and the shell. The ID tool needs traits and the shell; ranges and maps need taxa and the shell.

## Existing plans
- **gallformers-parity**: Keep, smaller. Five items move into the new plan; a518 and ba39 stay. Telemetry question df25/4807 is still open.
- **species-maps**: Merge and close. Its four items move into Ranges and maps, re-scoped onto range facts. Question ce43 is answered: any source can supply range data.
- **search**: Keep shaping. Re-scope onto the new model: names, published entry sections and facts, with SQLite FTS5. Bug 4742 stays here for later.
- **audit-2026-11**: Keep. Its inbox has duplicate pairs (for example 1728/3a7f, 50d4/4348) to settle once. Key rotation (33a4/4a4f): not now, low risk (Jeff).
