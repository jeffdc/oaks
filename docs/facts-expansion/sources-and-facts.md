# Sources and facts core

Phase 5 of the [Facts expansion](README.md). Sources as works, and the facts model every later phase uses. Needs Architecture groundwork. Taxonomy and Material and observations both need it.

The model is gallformers on the `taxogall` branch (`git -C ~/dev/gallformers show taxogall:<path>`); "port" below means copy from there and adapt. Gallformers is Postgres with a Carbonite audit log, so every port drops `Audit` and `Actor` and rewrites Postgres-only checks for SQLite. This is a draft: the open questions below are Jeff's to decide when the phase starts, and the architecture overview may change it.

## Decisions

Settled with Jeff (2026-11-21):

- A fact is tied to its sources. `facts` (kind, slot, standing); attributions (fact × source: stance, partial date, value as written); evidence (a material span, a document quote with page, or an observation); typed detail tables (trait, measure, range, parentage facts).
- Standing differs from gallformers' newest-wins: Jeff's Oak Compendium fact leads its slot; other sources sit behind it; values that disagree in a slot raise a conflict for Jeff. Measures compare by range overlap.
- Conflict resolutions: mine stands, update mine, not a conflict: variation, and a note. Recorded with who and when. Conflicts are shown and resolved, never hidden (PRODUCT.md).
- Facts from Jeff's writing count only once he accepts them.
- Sources are works: books, articles, websites, iNaturalist, Jeff's own field notes.
- `species_sources` free text stays verbatim as each source's description; nothing is promoted to a field. This phase doesn't touch it.
- No audit log and no undo. Copy gallformers' pure modules, not Carbonite, contests or its package contract.
- Contexts own their tables and talk through read models. Boundary enforces it (the first step below).
- Data goes in through the import endpoint, dry run first. No user-visible change in this phase.

The read model has to feed DESIGN.md's Standing Marks (agree, differs ≠, unreviewed or not recorded) and its Conflicts queue (decided rows show the verdict, who and when), and the `ed-conflicts.html` prototype's actions.

## Open questions

Each has a recommended default; Jeff decides.

- **Q1. A fact's subject while taxa don't exist.** This phase comes before Taxonomy. Default: `facts` has no subject column; the typed detail tables hold the subject, as in gallformers, and the read model takes a slot prefix. Tests use a test-only kind keyed to `species_id`; real subjects arrive as `taxon_id` with Taxonomy.
- **Q2. Which typed detail tables land here.** Default: the core plus `measure_facts` (it has no vocabulary to wait for), so the range-overlap rule is tested on a real schema. Parentage comes with Taxonomy, trait facts with Traits, range facts with Ranges and maps.
- **Q3. A slot with no Oak Compendium fact.** Default: no lead; the others show in the existing source order (`Oaks.Species.ordered_sources/1`: preferred, Oak Compendium, Oaks of the World, the rest by name), the state is unreviewed, and disagreements among them are marked differs but not queued as conflicts. The queue is for disagreement with Jeff.
- **Q4. The measure overlap test.** Default: compare full min–max ranges, falling back to the usual range when min or max is missing. Convert units where possible; mismatched units that can't be converted always conflict.
- **Q5. Stance and retraction.** Default: keep a `stance` column with only `confirm` allowed for now, so deny can come later; no source retraction.
- **Q6. What needs acceptance.** Default: only Oak Compendium attributions need Jeff's acceptance. Other sources' facts count once imported, since Jeff reads every dry run.
- **Q7. How far sources are normalized.** Default: add `kind` and an authored partial date beside `source_type` and `year`, which today's pages and the v1 API keep using; drop the old columns when the site moves (Taxon pages).
- **Q8. Boundary and today's crossings.** Adding Boundary is a new dependency, so Jeff OKs it. Default: record today's crossings as `dirty_xrefs` (the Species ↔ Sources cycle, and the web files that call Repo directly) and fix them when Taxonomy replaces Species.
- **Q9. Material spans before materials exist.** Default: a nullable `material_id` on evidence with no FK; Material and observations adds the FK and ports the quote locator.
- **Q10. The prototype's Undo on a decided conflict.** Default: it reopens the conflict, a state change, not an undo log.

## Step 1: Boundary

Architecture groundwork may take this step, when it decides how rule S1 is automated ([its section 5](architecture-groundwork.md#5-the-manual-rules)).

- Add `{:boundary, "~> 0.10", runtime: false}` and the `:boundary` compiler to `mix.exs`, as gallformers does.
- `use Boundary` on `Oaks`, every context (Accounts, Analytics, Articles, Images, Import, Search, Sources, Species, Stats, Storage, Taxonomy, Release) and `OaksWeb`. Utilities (Repo, ChangesetHelpers, JsonList, Licenses, Markdown, INaturalist, RateLimit, Version) export everything.
- Today's crossings, per Q8: `Oaks.Species` and `Oaks.Sources` reference each other's schemas (`lib/oaks/species.ex:14`, `lib/oaks/species/species.ex:12`, `lib/oaks/species/merge.ex:13`, `lib/oaks/sources.ex:13`); `dev_components_live.ex`, `analytics_live.ex`, `species_source_form_live.ex` and `health_controller.ex` call Repo. Facts starts clean.

Done when `mix compile --warnings-as-errors` fails on a new undeclared crossing, and dialyzer and credo pass.

## Step 2: Normalize sources

`sources` today (`lib/oaks/sources/source.ex`): free-text `source_type`, `name`, `description`, `author`, integer `year`, `url`, `isbn`, `doi`, `notes`, licence fields. Five rows: iNaturalist, Oaks of the World, Oak Compendium, Sibley, and the Botanical Gazette article.

- Migration: a `kind` enum (website, book, article, database, personal, legacy) backfilled from `source_type`; an authored partial date (`authored_on`, `authored_precision`) backfilled from `year`. Per Q7 the old columns stay.
- Port `lib/gallformers/sources/partial_date.ex` as `Oaks.Sources.PartialDate` (parses `YYYY`, `YYYY-MM`, `YYYY-MM-DD` into a first day and precision, and formats it back).
- Seed a "Legacy data" source (kind legacy, undated) through the import, dry run first. Taxonomy sources `parent1`/`parent2` parentage to it.

## Step 3: Facts core schema

Adapt gallformers' `priv/repo/migrations/20261024231000_create_facts.exs` and `lib/gallformers/facts/{fact,attribution,evidence}.ex`:

- `facts`: kind, slot (text, fixed once made), standing (stored, recomputed on every change to the slot).
- `attributions`: fact, source, stance (Q5), stated partial date, value as written, accepted at and by, declined at; unique per fact and source.
- `fact_evidence`: attribution, kind (quote, observation, material), quote, page, URL, span start and length, `material_id` (Q9), iNat observation id.
- Typed detail tables per Q2, each keyed by `fact_id` and owning its subject and slot rule, as gallformers' `lib/gallformers/catalog/facts/trait_fact.ex` and `range_fact.ex` do. Facts never depends on them.
- FKs restrict deletes. CHECK constraints in SQLite form (`strftime` for dates).

## Step 4: Standing and display rules

A pure `Oaks.Facts.Standing`, ported from `lib/gallformers/facts/standing.ex` and `standing/conflict.ex` with their table-driven test. Keep its shape (pure functions over plain maps returning standings and conflicts; numbered rules in the moduledoc) and its partial-date period comparison for a source restating a value. Replace its slot rule (newest current fact wins) with oaks' lead rule:

- **Lead:** the slot's Oak Compendium fact with an accepted attribution.
- **Behind:** every other fact with a counting attribution.
- **Conflict:** a behind fact whose value disagrees with the lead and has no resolution. Measures disagree only when their ranges don't overlap (Q4).
- **No lead:** per Q3.

Gallformers' name and synonymy contests (its rule 6) aren't ported.

## Step 5: Conflict records and resolutions

- `fact_conflicts`: slot, lead fact, other fact, resolution (open, mine stands, variation), note, resolved by and at. Raising a conflict is idempotent per pair; a new value in either fact reopens it.
- "Update mine" is an action, not a stored resolution: it edits the lead fact, and the slot is recomputed.
- `fact_notes`, from gallformers' `lib/gallformers/catalog/fact_note.ex`: a note on a fact that leaves its standing alone.
- Reopening per Q10.

## Step 6: Facts context and read model

- `Oaks.Facts`: create a fact, attribute, remove an attribution, accept, decline, resolve a conflict, add a note. Each recomputes the slot's standings and conflicts in its transaction. A much smaller version of gallformers' `lib/gallformers/facts.ex`; SQLite serializes writers, so no row locks.
- `Oaks.Facts.taxon_facts/1` returns, per slot: the lead (value, source, evidence) or none, the others, the conflicts, and a state (agree, differs, unreviewed, no data) that maps onto DESIGN.md's Standing Marks. It feeds the taxon page, the ID tool and the editor. Pattern: gallformers' `lib/gallformers/catalog/read_models/current.ex` and `gall_page.ex`.
- Its deps are Sources and Repo only.

## Step 7: Import

- Add `facts`, `attributions`, `fact_evidence` and the step 3 detail tables to `Oaks.Import.Tables.all/0`, after `sources`.
- Add a per-run hook to `Oaks.Import.Runner` (`lib/oaks/import/runner.ex:45`) that recomputes the standings and conflicts of every touched slot inside the run's transaction, so the dry-run report shows the resulting standings and new conflicts. Today `Tables` has only a per-record `prepare`.
- The acceptance columns can't be set through the import; only `Oaks.Facts.accept/2` sets them.
- Document the new tables in [docs/import.md](../import.md).

## Done when

- A fact is stored with its sources, evidence and standing.
- In tests, Jeff's accepted fact leads its slot, a disagreeing value raises a conflict, each resolution is recorded with who and when, a new value reopens a resolved conflict, and overlapping measures don't conflict.
- `Oaks.Facts` returns a subject's facts per slot with the lead, the others, conflicts and no data.
- Facts go in through the import after a dry run, and the dry-run report shows their standings.
- `mix compile` enforces Boundary.
- Nothing user-visible changes, and `make done-checks` passes.

## Acceptance checks

Tests build their own data with fixtures (`test/support/fixtures/facts_fixtures.ex`) and never read seeds.

| Area | Required evidence |
|---|---|
| Standing | Table tests of the pure module: lead wins, behind kept, disagreement raises a conflict, overlapping measures agree, no-lead slots per Q3, partial-date restatements |
| Conflicts | Each resolution recorded with who and when; idempotent raising; a new value reopens; reopening a decided conflict |
| Context | Recompute happens in the same transaction as the write; deletes are restricted |
| Read model | One test per state: agree, differs, unreviewed, no data |
| Import | A dry run reports standings and new conflicts without writing; an apply with its token stores them; acceptance can't be imported |
| Boundary | A new undeclared crossing fails compilation |

**Status:** not started.
