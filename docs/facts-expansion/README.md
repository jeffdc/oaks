# Facts expansion

Jeff's words and sourced facts in one model, edited in the site, shown through the new design. This doc is the overview: goals, settled decisions, the order of the phases and where each stands. Each phase has its own doc in this folder. A phase doc holds what is known and decided so far and a list of what is still to be worked out; it gains detail, in the style of [species-photos-plan.md](../species-photos-plan.md), when the phase starts.

## Goals

- **Who it's for.** Oak identifiers first (mostly iNaturalist identifiers, at a desk beside an iNat tab or on a phone under a tree), botanists and researchers second. Jeff is the only editor.
- **What it is.** The reference for telling oaks and their hybrids apart: one field identifier's tested knowledge, every claim traceable to his observations or to cited literature. North America first; the rest of the world stays a reference catalog until later. iNaturalist is the taxonomic backbone.
- **Jeff's words.** Oak Compendium prose is 100% Jeff's. Agents never write, paraphrase, summarize or merge it. They find his material, assemble it verbatim with sources, and propose facts with the quote behind each. Nothing counts until Jeff accepts it.
- **Facts.** Every fact is tied to its source, the way gallformers' taxogall does it. Jeff's facts lead; other sources stand behind them; conflicts are surfaced for Jeff, not hidden.
- **No hand SQL.** Every change goes through the app or the one import endpoint (every import is dry-run first, and Jeff reads the dry-run report before it applies). Hand-run SQL over Fly is designed out. There is no audit log or undo.
- **The look.** DESIGN.md and the prototypes in `design/prototype/` are the reference for every page.

Done when:

- Taxa, names, hybrids, varieties and synonyms live in the new taxonomy model, linked to iNat.
- Jeff's material (comments, ID remarks, manuscript, review notes) is in the database, private, with sources.
- Facts, traits and conflicts are sourced and reviewable; Jeff's lead.
- Jeff writes and publishes structured entries in the in-site editor; nothing agent-written can publish as his.
- The public site runs on the new design: taxon pages, comparisons, hybrids, ID tool.
- Every data change goes through the app or the import endpoint after a dry run; no SQL over fly ssh.

## Phases

| # | Phase | Needs | Status | Doc |
|---|---|---|---|---|
| 1 | Foundations | | Done | below |
| 2 | Site shell and design system | 1 | Done | below |
| 3 | Polish | 2 | Done | [polish.md](polish.md) |
| 4 | Architecture groundwork | 1 | Next; before any other new work | [architecture-groundwork.md](architecture-groundwork.md) |
| 5 | Sources and facts core | 4 | Not started | [sources-and-facts.md](sources-and-facts.md) |
| 6 | Taxonomy | 5 | Not started | [taxonomy.md](taxonomy.md) |
| 7 | Material and observations | 5 | Not started; can run beside 6 | [material-and-observations.md](material-and-observations.md) |
| 8 | Traits and fact review | 6, 7 | Not started | [traits-and-fact-review.md](traits-and-fact-review.md) |
| 9 | Authoring editor | 6, 7 | Not started | [authoring-editor.md](authoring-editor.md) |
| 10 | Taxon pages | 2, 6, 8, 9 | Not started; an intermediate species page is built | [taxon-pages.md](taxon-pages.md) |
| 11 | ID tool | 2, 8 | Not started | [id-tool.md](id-tool.md) |
| 12 | Ranges and maps | 2, 6 | Not started | [ranges-and-maps.md](ranges-and-maps.md) |

**Foundations (done).** Safe ground for everything after: editor login with password and TOTP, scoped agent tokens and the private API, the import endpoint with its dry-run token ([docs/import.md](../import.md)), and tests that build their own data instead of depending on seed counts. Nothing user-visible changed.

**Site shell and design system (done).** DESIGN.md in Phoenix: tokens, type, core components and layout, with Impeccable's detector clean on them. The component library and `/dev/components` came from here.

**Work done outside the phases.** The [species photos plan](../species-photos-plan.md) (PR #15, #17) built two pieces this plan had placed later: exemplar photos imported from iNat observations (part of Material and observations' observation roles) and an intermediate species page on today's data (a step towards Taxon pages, to be revisited when the facts model exists). The docs for phases 7 and 10 say how they fold in.

## Why this order

Foundations first: nothing else should write data until Jeff logs in properly and bulk changes come through the import endpoint. Architecture groundwork next, before any other new work: links by key, a decision on JSON columns, sharing with gallformers, the production toolchain and the rules' checks (Jeff, 2026-11-26). Sources and facts come before taxonomy because hybrid parentage, ranges and traits are sourced facts. Material can load in parallel with taxonomy. Traits and fact review need both taxa and material; so does the editor. The site shell could start right after Foundations; the public taxon pages need taxa, facts, entries and the shell. The ID tool needs traits and the shell; ranges and maps need taxa and the shell.

## Settled with Jeff (do not reopen)

- Stay on SQLite. Copy gallformers' design and its pure modules (not its Carbonite audit log).
- No audit log and no undo for now (Jeff, 2026-11-21). Add them later only if a need appears. An earlier draft had an audit log and transaction undo; that over-read Jeff's point, which was only that changes must not be pushed to SQLite by hand-run SQL. Ignore any leftover mention of auditing or "audited" writes; don't implement it or raise it. "Attributions" in Facts means a fact's sources, which stays. "Undo" in the review screens means reversing a review decision in the app, not an audit log.
- iNaturalist is the taxonomic backbone; departures are Jeff's sourced decisions.
- North America first for traits and the ID tool.
- Varieties and subspecies are taxa with their own pages under their species.
- Agents run in Claude Code outside the app and submit bulk changes through one import endpoint, always as a dry run first; the app makes no LLM calls.
- Facts from Jeff's writing: an agent proposes, with the verbatim quote; Jeff accepts.
- The editor lives in the site, editor-only. Reviewing the live agent-assembled text is the same screen as writing.
- Entries follow one structure: key sentence (the fragment on the taxon page), account, historical context, more to come.
- No more bulk exports from iNat. ID mode and capture mode tie individual observations to the database.
- One template for every taxon page; sections show by data, not by whether Jeff has covered the taxon.
- Comparisons are a mode of the taxon page at `?vs=`, deep-linkable; the write-up reader is at `?read=`.
- Copyright: facts can't be copyrighted; anyone may use them. Jeff's prose and the entry structure are copyrighted.
- Other authors' text stays as it is today: the Sibley entries are extracted facts, and the Oaks of the World text is fine to show.
- Any source can be a source of range data.
- ID mode starts as a feature list plus a link; no saved sessions to begin with.
- The book is out of scope for now; the model keeps both options open.

## Design references

- PRODUCT.md: product truth (users, positioning, brand commitments, principles).
- DESIGN.md (and `.impeccable/design.json`): the visual world and every settled component.
- `design/prototype/`: the taxon page set (`shumardii.html`, `compare.html`, `x-riparia.html`, `hypoleucoides.html`, `acutissima.html`, `shumardii-sources.html`), the ID tool (`id-filter.html`, `id-hybrid.html`, `id-mode.html`, `id-intro-this-or-that.html`) and the editor (`ed-entry.html`, `ed-facts.html`, `ed-conflicts.html`). Their data is illustrative. `species-today.html` is the intermediate species page built by the species photos plan.
- `.impeccable/surfaces/`: the surface briefs with Jeff's rules for each page (one-template rule, range overlap, no eastern bias, structured entries, key sentence as fragment).
- All UI work uses the impeccable skill, sized as AGENTS.md says, and the component library (docs/COMPONENTS.md).

## Model sketch

The model this plan builds towards, as agreed on 2026-11-21. It is the target, not the current state: as each phase lands, what it built is described in the [architecture doc](../architecture/README.md), with a decision entry.

- **Contexts.** Business logic splits into contexts that own their tables and talk through published read models, as in gallformers: Taxa, Sources (works, materials, observations), Facts, Traits, Entries, Import. Nothing reads another context's tables directly.
- **Taxa.** `taxa` (rank: genus, subgenus, section, subsection, complex, species, subspecies, variety, form, nothospecies, formula hybrid), `taxon_names` (accepted, synonym, misapplied; authorship), a closure table for ancestry, and the iNat taxon id. Named hybrids and formula hybrids are taxa; their parentage is a sourced fact. An intersectional hybrid sits at the lowest rank both parents share. Port gallformers' `Taxa.Ancestry`, tree validator and `NameNormalizer`.
- **Sources and material.** Sources are works (books, articles, websites, iNaturalist, Jeff's own field notes). Materials are Jeff's verbatim texts (iNat comments and ID remarks, manuscript paragraphs, review notes), each with date, URL, authorship (Jeff, cited, not Jeff), taxon links, a set-aside flag and a duplicate group. Materials are private and never in the public API. Observations are iNat observations with photos, licence and roles: exemplar photo, evidence, material, trait illustration.
- **Facts.** `facts` (kind, slot, standing), attributions (fact × source: stance, partial date, value as written), evidence (a material span, a document quote with page, or an observation), and typed detail tables: trait facts, measure facts (min, usual range, max, unit), range facts (place, native or introduced), parentage facts. Standing differs from gallformers' newest-wins: Jeff's Oak Compendium fact leads its slot; other sources sit behind it; values that disagree in a slot raise a conflict for Jeff (mine stands, update mine, not a conflict: variation). Measures compare by range overlap.
- **Traits.** A global trait vocabulary (organ, kind: categorical, range or count, unit), values, and source-term mappings like gallformers' `trait_term_mappings`. No eastern North American or red/white oak assumptions. Jeff approves the vocabulary.
- **Entries.** `entry_structure` (the shared sections and their purpose), entries, sections, immutable section versions, and provenance spans inside each version: inserted from material (with the material span), typed by Jeff, or agent wording (pre-existing). Entry text can only be written by Jeff's own session in the editor; the import path rejects it. Only sections Jeff marks written publish.
- **Import.** One private endpoint for every bulk change ([docs/import.md](../import.md)): JSON shaped like the data model (one key per table, field names as in the Ecto schemas, local refs between records in one body) with a scoped token. Each record goes through its changeset, the whole body applies in one transaction or not at all, with errors reported per record. A dry run returns a token tied to the exact body, and the real call is refused without it. Re-sending an applied import is a no-op. Each model adds its tables to the endpoint as it lands. No JSON Schema contract, staging, diff screen or import undo.
- **API.** The public read-only v1 keeps working through an adapter until the site moves. A v2 serves the new model (taxa, names, published entry sections, facts with sources) to the public. A private API serves agents.
- **Gallformers.** Copy the proven pure modules now (standing rules, partial dates, quote locating, name normalizing, ancestry), but not its import contract. UI components (the photo viewer, then the fragment-and-reader) and the guardrails are shared as code through heartwood, a package both apps depend on ([Architecture groundwork](architecture-groundwork.md#3-sharing-with-gallformers), Jeff, 2026-11-26).

## Moving today's data

- Species rows become taxa and names: hybrid names parsed (×, formula, misspellings), two-word infraspecific names become child taxa with ranks, autonyms handled, synonyms become names, `parent1`/`parent2` become parentage facts sourced as legacy data.
- `species_sources` free text stays verbatim as each source's description, shown behind Jeff's facts; nothing is promoted to a field.
- The 2026-11-20 short Oak Compendium text loads into the editor as agent wording, flagged for review. Jeff's × *fontana* edit (Laughlin's description) is kept as his.
- Lobe and tooth counts become measure facts sourced to Jeff's counts; the research workbook's literature values become other sources' facts.
- Jeff's notes material (kept locally in `compendium-notes/`, outside git) loads as materials: snippets, manuscript paragraphs with authorship, review notes; Jeff's keep/drop sorting maps to set-aside; other people's comments are excluded. Jeff checks a sample before it applies.
- Every load goes through the import endpoint: dry run first, and Jeff reads the dry-run report before it applies. Schema changes are migrations; data changes are imports.

## Open questions

The index of questions that cut across phases; each phase doc lists its own.

- **Entry sections** (Authoring editor): the full section list after key sentence, account and historical context. Default: those three for now, more added as Jeff needs them.
- **Publishing** (Authoring editor): does marking a section written publish it, or do sections wait for a Publish? Default: marking it written publishes it.

## Other plans

Separate from this one, each in its own doc: [gallformers parity](../gallformers-parity-plan.md) (done), [search](../search-plan.md) (shaping; after Taxon pages) and the [November 2026 audit](../audit-2026-11-plan.md) (done). Work that belongs to no plan is in the [backlog](../backlog.md).
