# Architecture groundwork

Phase 4 of the [Facts expansion](README.md). Core architecture work that comes before any other new work (Jeff, 2026-11-26): keys instead of names for links, a decision on JSON in TEXT columns, how code is shared with gallformers, the production toolchain, and what becomes of each manual architecture rule. It starts from the [architecture baseline](../architecture/README.md) and its [first review](../architecture/reviews.md).

Order (Jeff, 2026-11-26; amended 2026-11-27): the public API goes off the air first, then links by key and the JSON columns, as six pull requests ([The pull requests](#the-pull-requests-for-sections-02)); sharing with gallformers was decided in its own discussion, and its step 1 (heartwood's guardrails) comes before the manual rules, which come last. Each decision gets an entry in [decisions.md](../architecture/decisions.md).

## Done when

- `/api/v1` answers 410 in production, and its code and tests still pass with the flag on (section 0).
- Every species has a `taxon_id`, every taxon but the genus a `parent_id`, and every hybrid its `parent1_id` and `parent2_id`. No code rewrites names to keep links intact, and merge is gone (section 1).
- Synonyms, common names and article tags are rows; links are cast through one embedded schema; rule D4 has no violations (section 2).
- The name-link and JSON-list columns are dropped.
- Oaks runs on `heartwood_guardrails` and on `heartwood_ui`'s photo viewer (section 3, steps 1 and 2).
- Every rule in rules.md is automated, covered by the reviewer prompt, or retired; the reviewer prompt exists and has produced a review entry.
- The architecture doc describes the result, and `make done-checks` passes.

## 0. The public API off the air

**Decided (Jeff, 2026-11-27):** `/api/v1` goes off the air while the Facts expansion lands, so nothing has to keep its JSON as the model changes underneath it. The code stays: controllers, spec, schemas and serializers remain in the tree, run in the tests and change shape freely with the model, with no compatibility promise. It comes back on, as v2 or a reshaped v1, when the model is done. The private API (`/api/private/v1`) stays served; every import in this plan uses it.

**How:**

- A plug at the head of the `:api` pipeline answers 410 with a JSON body pointing at the site while `config :oaks, :public_api` is false. It is false in `config.exs` (dev and production) and true in `test.exs`. The plug reads it with `Application.get_env/3` on each request, so one test can turn it off. The pipeline covers `/api/v1` and `/api/v1/docs`.
- `OaksWeb.Plugs.ApiHost`: while off, `api.oakcompendium.org` answers 410 on every path but `/health` and the private API (`/api/private/`), including `/` (today a redirect to the docs). On, it behaves as today.
- Removed: the `API_VERSION` file, `Oaks.Version.api_version/0` (`ApiSpec` takes the app version), the About page's "API:" text and its test, and CI's API Version Check job and the `API_VERSION` path filter. `mix smoke_test` replaces its API checks with one that `/api/v1/stats` answers 410, and keeps its page checks.
- **GitHub, by Jeff before the PR can merge:** the `main-no-push` ruleset requires five checks, API Version Check among them. Once the job is gone it never reports, so it comes out of the ruleset's required checks first, or the PR can't merge.
- Docs: W9 retired in rules.md (W2 stays true of the code); O2's check list and "Checks that exist" lose the job; the architecture README and AGENTS.md's Authentication section say the API is off the air.

**Tests:** with the flag off, `/api/v1/species`, `/api/v1/docs` and `api.oakcompendium.org/` answer 410, while `/health` and the private API's token and import endpoints answer as before.

## 1. Links by key, not by name

Jeff: links by name are not good and need fixing.

**Known (2026-11-27, dev copy of production):**

- Species point at their taxa by name: `subgenus`, `section`, `subsection` and `complex` match `taxa` by name and level. 671 of the 733 species are placed. The other 62 have no rank at all, and every one is a named hybrid. 10 species sit in a complex directly under a section.
- Taxa point at their parent by name (`taxa.parent`). There are 46 taxa: 2 subgenera, 8 sections, 19 subsections and 17 complexes. The 44 below the subgenera have a parent name. Names repeat across ranks (`Quercus` is a subgenus and a section; `Cerris` a subgenus, a section and a subsection), so 13 parent names are ambiguous on the name alone. Read as the taxon of that name at the nearest rank above the child, every one resolves, and every placed species' stored ranks form one consistent chain (0 mismatches).
- Species point at other species by scientific name: `parent1` and `parent2`. All 239 hybrids have both, every one matches a species' name exactly, and none is the hybrid itself or the same species twice. The JSON lists `hybrids` (120 species), `closely_related_to` and `subspecies_varieties` also hold names. All 478 `hybrids` entries are the reverse of the children's parents, so the column is redundant. `subspecies_varieties` is empty in every row. `closely_related_to` is set on one species (`margaretiae`: `["stellata","austrina"]`) and is no longer shown (Jeff, 2026-11-25: to be dropped).
- `Oaks.Species.References` keeps the name links intact by rewriting every mention when a species is renamed, deleted or merged. `Oaks.Taxonomy` rewrites `species` rows when a taxon is renamed (an S1 violation), and maps each level to a species column (`@level_fields`, the `@species_count_sql` fragment). The name fields are read in `Oaks.Species`, `Oaks.Taxonomy`, `Oaks.Search`, `Oaks.Stats`, `OaksWeb.TaxonPath`, `OaksWeb.SpeciesName`, `DesignComponents`, the API controllers and `api_schemas.ex`, and the home, species list, species, search, taxonomy, species form, taxon form and merge pages.
- `taxa` has a `CHECK` on `level` (the four ranks) and `UNIQUE(name, level)`. `idx_species_subgenus`, `idx_species_section` and `idx_taxa_parent` index name-link columns; SQLite won't drop an indexed column until its index is dropped.
- Ecto's SQLite adapter turns foreign keys on, so a `restrict` key is enforced.

**Decided (Jeff, 2026-11-26):** foreign keys on today's tables, now, rather than bringing Taxonomy's model forward: `taxa.parent_id`; a taxon key on species; `parent1_id` and `parent2_id`; `hybrids` derived by query and its column dropped; `closely_related_to` and `subspecies_varieties` dropped. `References` and Taxonomy's species rewrite go away.

**Decided (Jeff, 2026-11-27):**

- **Merge leaves the app** until Taxonomy brings synonymy back properly. Rename still records the old name as a synonym. Deleting a species that is a hybrid's parent is refused, and the dialog lists those hybrids.
- **Today's data moves in migrations; content changes go through the import endpoint.** A migration that only puts the same data in a new shape (names resolved to keys, JSON lists into rows) runs with the schema change at boot, so there is never a window where the code reads columns nobody has filled. A change to what the data says (the placements below) is an import, dry run first, which Jeff reads before it applies. This refines "schema changes are migrations; data changes are imports" in the [Facts README](README.md#moving-todays-data).
- **The 70 hybrid placements change in this phase.** The 62 unplaced hybrids are placed at their parents' lowest shared taxon, and so are the 8 whose stored placement disagrees with their parents' (of the nine listed in [taxonomy.md](taxonomy.md), × *autumnalis* already matches). This is the model sketch's rule: a hybrid sits at the lowest rank both parents share.

The 62, computed from the dev copy: 37 to a section, 4 to a subsection, 4 to a subgenus and 17 to the genus. The 17 are crosses between the two subgenera (*ilex*, *coccifera*, *suber* or *cerris* with a species of sect. *Quercus*). No parent is itself one of the 62, so one pass settles them all. The 8:

| Hybrid | Stored | Parents' lowest shared taxon |
|---|---|---|
| × *alvordiana* | complex *dumosa* | sect. *Quercus* |
| × *comptoniae* | sect. *Quercus* | subg. *Quercus* |
| × *harbisonii* | sect. *Quercus* | subg. *Quercus* |
| × *hillii* | sect. *Quercus* | subsect. *Prinoideae* |
| × *hispanica* | subsect. *Suber* | sect. *Cerris* |
| × *introgressa* | subsect. *Prinoideae* | complex *prinoides* |
| × *kinseliae* | complex *dumosa* | subsect. *Dumosae* |
| × *munzii* | sect. *Quercus* | subsect. *Dumosae* |

**Proposed (for Jeff to confirm):**

- **One key to the lowest taxon.** `species.taxon_id` points at the most specific taxon, and the ranks above come from walking `taxa.parent_id`. This is the shape gallformers' taxogall uses and Taxonomy adopts: one row per taxon with a rank and a parent, classification from ancestry. A key per rank would repeat the tree in every species row and could disagree with it.
- **The genus is a row.** The 17 need a parent above the subgenera, so `taxa` gains a `genus` rank and one row, *Quercus*, as the root; the two subgenera point at it, so only the genus has no parent. It is created by the keys migration: the band already shows a genus step on every page, so the row changes nothing visible.
- **The genus's page is `/taxonomy`.** `OaksWeb.TaxonPath` already links its genus step there. The index lists the species placed directly in the genus (the 17, and any species with no `taxon_id` until the import applies), where it lists the species with no subgenus today. Taxonomy URLs keep their name paths (`/taxonomy/Quercus/Quercus`), resolved by walking down from the genus.
- **A parent ranks above its child.** The ranks are ordered (genus, subgenus, section, subsection, complex), and a taxon's parent must rank above it, which makes cycles impossible without walking the tree. `Oaks.Taxonomy` checks it on create and update, and the import's `prepare` hook for taxa does the same.
- **The forms pick keys.** The species form has one placement select over every taxon, in tree order with the rank in each label, in place of the four rank selects, through the library's `<.input type="select">`. Its two parent fields stay text inputs, since a select of 733 species is unusable: the context matches the typed name with `Oaks.Species.References.key/1` and stores the key, and a name that matches no species is a field error. The taxon form's parent select lists only taxa ranked above the level chosen.
- **The changeset requires `taxon_id`** once the import has placed the 62 (the drops PR); the SQLite column stays nullable.

## 2. JSON in TEXT columns

**The rule (Jeff, 2026-11-26; rule D4):** JSON in a TEXT column only for a value that belongs to its row, that the database never queries, filters or joins on, and that never points at another row. The app casts it through an embedded schema or a typed array, so it is still validated.

**Decided, column by column (Jeff, 2026-11-26; counts 2026-11-27):**

| Column | Holds | Decision |
|---|---|---|
| `species.hybrids` | 120 species, names; the reverse of their children's parents | Drop; derive by query (section 1) |
| `species.closely_related_to` | 1 species, names; not shown | Drop |
| `species.subspecies_varieties` | empty | Drop; varieties become child taxa in Taxonomy |
| `species.synonyms` | 426 species, 1,160 names with their authority in the string; all valid JSON strings, no blanks, no repeats within a species; some names malformed (listed in [taxonomy.md](taxonomy.md)) | Move to the `names` table |
| `species_sources.local_names` | 359 rows, 648 common names; no blanks, no repeats within a row; read for the title's common name, the source tabs, the comparison page, search and the API | Move to the `names` table |
| `species.external_links` | 105 species, 224 entries `{name, source, url, logo}`; 102 carry the dead `logo`; every URL https | Keep as JSON, through one links embedded schema with validated URLs; drop `logo` |
| `taxa.links` | 43 taxa, one `{label, url}` each (iNaturalist) | Keep as JSON, through the same embedded schema as species' links |
| `articles.tags` | 1 article, `["identification"]`; filtered with LIKE on the JSON text | Move to a tags table: cheap, and tags will likely be used more |
| `api_tokens.scopes` | scope strings, in code only | Keep |
| `image_cleanups.paths`, `attempt_ids` | object paths and IDs, read by the cleanup worker only | Keep |

**The `names` table** holds synonyms and common names, keyed to species for now. It is shaped like the names model the Taxonomy phase plans (accepted, synonym and misapplied names with authorship), so Taxonomy extends it rather than replacing it.

**Proposed (for Jeff to confirm):**

- **`names` columns:** `species_id` (FK, delete cascades), `kind` (`synonym` or `common_name`), `name`, `source_id` (common names only) and `position` (the order within a species' synonyms, or within one source's common names). Common names also carry a composite foreign key `(species_id, source_id)` to `species_sources` (which is unique on that pair) with delete cascading, so removing a source's data on a species removes its common names; synonyms, with a null `source_id`, are untouched by it. Uniqueness is two partial unique indexes: `(species_id, name)` for synonyms and `(species_id, source_id, name)` for common names. (One index over all four columns wouldn't hold: SQLite treats every null `source_id` as distinct.)
- **Verbatim, no cleaning.** This is the shape-only migration (section 1), so names move exactly as stored, authority inside the string, as the page already shows them (`<.sci_name>` splits the authority off for display). There is no `authority` or `language` column yet: every row would leave them empty. Taxonomy adds them with the `NameNormalizer` that splits names, and cleans the malformed synonyms there.
- **The title's common name** stays the first name, by `position`, in the chosen source, so no display changes.
- **Tags:** `article_tags(article_id, tag)` with a unique index on the pair and delete cascading, not a `tags` table plus a join. Tags have no data of their own to justify a table.
- **One links shape:** `{name, url, source}`, `source` optional. Species' links keep their fields less `logo`; taxa's `label` becomes `name`. The embedded schema accepts only `http` and `https` URLs and requires `name` and `url`. A custom Ecto type casts the TEXT column to a list of these structs, since `embeds_many` expects a JSON column type. It belongs to neither Species nor Taxonomy, so it is its own small module (`Oaks.Links`).

## The pull requests for sections 0–2

Six pull requests to main, one at a time, each deployable on its own: CI, the deploy and the smoke test run on every one as usual. The schema follows expand and contract: PRs 3 and 5 add the new shape and move every reader and writer to it, but leave the old columns in the database, unread; PR 6 drops them once the new shape has run in production. Until PR 6, a revert PR can restore the old code against a schema it still fits (its columns show the data as of PR 3 or 5's deploy). After PR 6, a Litestream restore is the only way back.

**Every migration PR is rehearsed** on a fresh `make download-db` copy right before it merges (`DATABASE_PATH=<copy> mix ecto.migrate`). Each migration is self-contained SQL and Elixir, calls no app module (they change after it), and raises unless its own counts come out as expected, so a mismatch fails the rehearsal rather than reaching production. A migration that raised at boot would leave production down until a fix deploys; the rehearsal is what prevents that, and Jeff makes no edits between the rehearsal and the deploy.

### PR 1: the public API off the air

Section 0, all of it. Jeff removes API Version Check from the ruleset's required checks before it merges.

Done when the production config answers 410 on `/api/v1`, its docs and `api.oakcompendium.org`; the API's tests pass with the flag on; no `API_VERSION` reference remains; and `mix smoke_test` passes against the deploy.

### PR 2: merge removed

Removed end to end: `Oaks.Species.Merge`, `SpeciesMergeLive` and its route, the "Make synonym of…" item and merge picker in `species_detail_live.ex`, `Images.merge_species_images/3`, the `.merge-*` block in `app.css`, the merge examples in `dev_components_live.ex` (three menu items) and in `edit_menu`'s doc (`core_components.ex`), the merge mentions in docs/COMPONENTS.md (the `frame` width, the genus rule's "merge references" and "merge page's synonyms", the edit-menu row, the dialog row's "or merge"), and the tests (`merge_test.exs`, `merge_photos_test.exs`, `species_merge_live_test.exs`, the merge cases in `species_detail_live_test.exs`). Rename and delete keep using `References` until PR 3.

Baselines lowered with it (`mix heartwood.baseline`): the `app.css` line budget; in rules.md, W1's merge-picker entry, U1's `species_merge_live.ex` entries and U6's `.merge-spinner`. The architecture README's context table loses `Merge`.

Done when nothing in `lib/`, `test/`, `assets/` or docs/COMPONENTS.md mentions merge, and `make done-checks` passes.

### PR 3: keys

Section 1's schema and code, the same placements as today.

**Migrations:**

1. Rebuild `taxa` (SQLite can't change a `CHECK`): `level` admits `genus`, `parent_id` (FK `taxa`, restrict, indexed) is added, rows are copied with their ids. A *Quercus* genus row is created; the subgenera's `parent_id` is the genus, and every other taxon's is its parent name at the nearest rank above. Raises unless there is exactly one genus, only it has no parent, and every parent ranks above its child; the checks are structural, so they hold on the empty test database too. The rehearsal checks the production counts (47 taxa, 1 genus).
2. `species` gains `taxon_id` (FK `taxa`, restrict) and `parent1_id` and `parent2_id` (FK `species`, restrict), indexed. `taxon_id` is the taxon matching the lowest of `complex`, `subsection`, `section` and `subgenus` by name and level; the parents match `scientific_name` exactly. Raises unless every species with a stored rank has its taxon and every non-empty parent name has its key; the rehearsal checks that 671 species are placed and 239 hybrids have both parents.

**Code:**

- The old fields leave the Ecto schemas (`Species`: `subgenus`, `section`, `subsection`, `complex`, `parent1`, `parent2`, `hybrids`, `closely_related_to`, `subspecies_varieties`; `Taxon`: `parent`), so the compiler finds every reader and nothing can write them. The columns stay until PR 6.
- `Oaks.Species.placement/1`, the hybrids and siblings queries and the home page's hybrid counts read keys; a species' hybrids are a reverse query on the two parent keys. `Oaks.Taxonomy` walks `parent_id`: `resolve_path/1`, the species in a taxon, child taxa, species counts and `taxon_usage/1`; `@level_fields` and `@species_count_sql` go. Search's taxon counts and ancestry paths, `OaksWeb.TaxonPath` (its genus step is now the row) and the API serializers follow.
- Rename changes only the species' own row and still appends the old name to its synonyms; renaming a taxon changes only its row. `References` keeps `key/1` and the synonym list helpers (`decode/1`, `encode/1`) until PR 5; `find/1` and `rewrite/4` go. The S1 baseline loses Taxonomy's species rewrite.
- Deleting a species that is a parent is refused (the key does it); `references_to/1` becomes the hybrids that name it, for the dialog. Deleting a taxon with species or children is refused as today, now by keys.
- The forms, the taxon rank rule and the genus on `/taxonomy`, as proposed in section 1.
- Import: `taxa` moves ahead of `species` in `Tables.all/0` (order: sources, taxa, species, species_sources), the changesets cast the new keys, and `refs` declares `taxa.parent_id`, `species.taxon_id`, `parent1_id` and `parent2_id`.

**Evidence:** a throwaway script run on the rehearsal copy, before and after the migrations, prints every species' placement band and parents and every taxon's ancestry; the two outputs are identical.

Done when no `lib/` code reads a name-link field, the before-and-after outputs match, deleting a hybrid's parent is refused with the hybrids listed, and `make done-checks` passes.

### PR 4: the 70 placements

Content, so an import (no code; PR 3 already handles every rank). A throwaway script builds the body from a fresh `make download-db`: 70 `species` updates, each `{"$find": {"scientific_name": …}, "taxon_id": {"$find": {"level": …, "name": …}}}`, so the body names what it changes rather than carrying ids. Beside it the script writes a table for Jeff: hybrid, stored placement, new placement, parents and their placements.

Dry run against production; Jeff reads the report and the table (62 placed, 8 moved); then the apply. Afterwards [taxonomy.md](taxonomy.md)'s nine-hybrids entry says it is settled.

Done when the apply reports 70 updates, a re-send is a no-op, and the 17 genus-level hybrids are listed on `/taxonomy`.

### PR 5: names, tags and links

Section 2's schema and code.

**Migrations:** create `names` and `article_tags` as proposed; move the 1,160 synonyms and 648 common names (`position` from their list order) and the 1 tag; rewrite `species.external_links` without `logo` and `taxa.links` with `name` for `label`, in place. Raises unless the row counts match those and every link has a `name` and an http(s) `url`.

**Code:**

- `Oaks.Species.Name` and the context functions over it. The editors keep their textareas (synonyms on the species form, common names on the source form, tags on the article form): the context turns the text into rows and back, so a save round-trips.
- Readers move: search (synonyms and common names), `find_synonym/1` (a query on `names` in place of LIKE over the JSON text), the title's common name, the source tabs, the comparison page, the species page's synonyms, rename (adds a `synonym` row), article tags (listing and filtering), and the API serializers.
- `Oaks.Links` casts both link columns; the species page and the taxon form read the structs.
- The old fields leave the schemas (`Species.synonyms`, `SpeciesSource.local_names`, `Article.tags`); the columns stay until PR 6.
- Retired, each with its entry in `test/support/retirements.exs` first: `Oaks.JsonList` (nothing uses it once these fields go) and `Oaks.Species.References`, whose `key/1` moves to `Oaks.Species.Name`. `Oaks.Species`' JSON-array helpers that served only these fields go too.
- Import: `names` joins `Tables.all/0` after `species_sources`, with `species_id` and `source_id` as refs.

**Evidence:** the same throwaway before-and-after script, extended with every species' synonyms, title common name and per-source common names: identical outputs.

Done when the outputs match, search finds a species by a synonym and by a common name, each editor's save round-trips, a link with another scheme is refused, and `make done-checks` passes.

### PR 6: the old columns dropped

After PR 5 has run in production long enough for Jeff to trust it. A fresh `make download-db` first, as the last copy in the old shape.

- Drop `idx_species_subgenus`, `idx_species_section` and `idx_taxa_parent`, then the columns: `species.subgenus`, `section`, `subsection`, `complex`, `parent1`, `parent2`, `hybrids`, `closely_related_to`, `subspecies_varieties` and `synonyms`; `species_sources.local_names`; `articles.tags`; `taxa.parent`. `margaretiae`'s `closely_related_to` value goes with its column, as Jeff decided on 2026-11-25.
- `Species.changeset` requires `taxon_id`.
- D4 reaches 0; rules.md, the architecture README (its context and table lists) and decision entries for sections 0–2 change in the same PR.

Done when the rehearsal passes, `make done-checks` passes, and rules.md shows D4 at 0.

## 3. Sharing with gallformers

Code shared with gallformers lives in heartwood (`jeffdc/heartwood`). Decision: [decisions.md](../architecture/decisions.md).

**Decided (Jeff, 2026-11-26):**

- Oaks depends on two heartwood packages, as git dependencies pinned by tag:
  - `heartwood_guardrails` (dev and test only): the ratchet framework behind `OaksWeb.Conformance`, the duplicate-code ratchet, retirements, the git hooks and commit gate, the reuse review, and `check-toolchain`.
  - `heartwood_ui` (runtime): the photo viewer, then the fragment-and-reader, as LiveView colocated hooks and CSS. Oaks imports the hooks from `phoenix-colocated/heartwood_ui` in `app.js` and `phoenix-colocated/heartwood_ui/colocated.css` in `app.css`, which needs Tailwind 4.2.3 or later with `NODE_PATH` in its tailwind config.
- Oaks keeps its own rules and settings: `OaksWeb.Conformance`, its baselines in `test/support/`, the `duplicates` config in `.credo.exs`, its retirements list, and the commit gate's prose paths and reviewer checklist in `dev/guardrails/`.
- Oaks themes a shared component with one adapter block that maps its tokens onto the component's custom properties (`.oc-photos`); anything oaks-specific stays in its own wrapper (`<.species_photos>`).
- Oaks moves to a new heartwood tag when it chooses, following the changelog's "Upgrade:" steps. A bug in a heartwood piece is fixed in heartwood (with `HEARTWOOD_PATH` pointing oaks at a local checkout), never in `deps/`.
- Gallformers' pure domain modules are copied, not shared: each copy starts with an origin line (repo, path, commit, what was adapted), and oaks owns it after that. `Taxa.Ancestry` and the tree validator are rewritten for SQLite.
- CI workflows aren't shared.

**Steps:**

1. **Oaks on `heartwood_guardrails`.** Done 2026-11-26 (PR #31); on v0.1.1 since.
2. **The photo viewer from `heartwood_ui`:**
   - **2a.** Tailwind 4.3.5 with `NODE_PATH` in the tailwind config (PR #36).
   - **2b.** Heartwood v0.2.0 ships the photo viewer.
   - **2c.** Done 2026-11-27 (PR #38). Oaks on `heartwood_ui` v0.2.0: the dependency and the two imports. Oaks keeps `<.species_photos>` and `.oc-photos`, with `.oc-photos` mapped to v0.2.0's custom properties. The viewer's filmstrip replaces oaks' paged rail and its step buttons; the 4/5 and 4/3 ratios stay as `.oc-photos` settings. Deleted: `OaksWeb.PhotoViewer`, `assets/js/photo_viewer.js`, the `pv-` block in `components.css` and the tests that moved to heartwood. The dev components page and the docs are updated to match.
3. **The fragment-and-reader** is built in `heartwood_ui` ([Taxon pages](taxon-pages.md)).

## 4. The production toolchain

**Decided (Jeff, 2026-11-26): keep it.** Production doesn't use Nix: the Dockerfile builds the release in `hexpm/elixir:<elixir>-erlang-<otp>-alpine-<alpine>` and runs it on `alpine`, built by Fly's remote builder. Nix provides the toolchain for dev and CI, and `scripts/check-toolchain` keeps the Dockerfile's versions equal to the flake's. Building the image with Nix would mean leaving Fly's builder for CI, which isn't worth it. Gallformers works the same way.

## 5. The manual rules

After sections 0–2 (Jeff, 2026-11-26; amended 2026-11-27), and on top of section 3's step 1 (oaks on `heartwood_guardrails`).

**Decided (Jeff, 2026-11-26):**

- **Enforcement follows gallformers' conformance-test pattern** in both projects: a scanner module with one rule per pattern (each with a hint naming the right token or component), its own unit tests, a JSON baseline of counts per file and rule, a mix task that updates the baseline, and an ExUnit test that fails when a count goes over its baseline or under it without the baseline being lowered. It runs in `mix test`, so in `precommit` and CI. The framework is in `heartwood_guardrails` (section 3); oaks' rules are in `OaksWeb.Conformance`, starting with check-ui's, and `scripts/check-ui` is retired.
- **One `check-toolchain` for both projects,** in `heartwood_guardrails`: gallformers' loop over every Dockerfile that exists and its Typst check (when the flake provides Typst), plus oaks' `MIX_TAILWIND_PATH` check.
- **Oaks adopts gallformers' other guardrails** through heartwood (section 3): the duplicate-code ratchet, retirements, the pre-push hook test, and the reuse review before each commit with its commit gate.
- **The architecture reviewer** is an assistant Jeff runs periodically, with different models for a mix of opinions. Its first job is finding where new rules are needed and which rules should be automated; judging the manual rules comes second.
  - A prompt in the repo that any model can follow: plain markdown, read-only, nothing specific to one harness.
  - A packet script that gathers the same evidence for every run: the context dependency graph from `mix xref`, every ratchet's output against its baseline, the commits since the last review, `mix heartwood.status` (the pinned heartwood tag against the latest), and the architecture docs. The reviewer starts from the packet and is free to explore beyond it.
  - A report in a fixed shape, with paths and evidence, confirmed in the code: proposed new rules (the pattern, where it occurs, why it matters, how it could be checked); manual rules that could be automated, and how; violations of the manual rules; rules worth retiring; places where the architecture doc no longer matches the code.
  - Reports are kept local, one per model per run. Jeff combines them, with an agent if he likes, into one entry in [reviews.md](../architecture/reviews.md); a finding several models raise independently carries more weight.
  - **Where it lives (Jeff, 2026-11-26):** in `heartwood_guardrails`, beside the reuse review, so oaks, gallformers and heartwood share one reviewer; built in heartwood v0.1.1 (heartwood PR #5). `mix heartwood.architecture` writes the packet, `review/architect.md` is the prompt, and `bin/record-architecture <run> <model>` keeps a report. The task graphs the Mix project it runs in; each app sets its architecture docs, its own questions for the reviewer (oaks: `dev/guardrails/architecture.md`, on the rules that need judgement) and how many path segments name a context in `dev/guardrails/config.sh`, and lists its ratchets in `config :heartwood_guardrails, ratchets:`. The commits since the last review are those after the last commit that changed the app's `reviews.md`. Reports go in git's common directory, `<app>-architecture/<run>/<model>.md` (a run is the date and HEAD), shared by every worktree of a clone, with nothing to gitignore. Heartwood gets a small `docs/architecture/` of its own (README, rules, reviews) so the reviewer works the same in all three repos.

**Then, rule by rule:** go through every rule in [rules.md](../architecture/rules.md) whose check is manual or partial, and the gaps and proposed rules in the [baseline review](../architecture/reviews.md), and decide for each: a conformance rule, Boundary (for context dependencies; now Sources and facts core's first step, it may move here), a test that walks the router, a CI change (`deps.unlock --check-unused`; Dialyzer has run in CI since PR #19, and check-ui's rules run in `mix test` as `OaksWeb.Conformance` since PR #31), the reviewer, or retire it. A first triage was discussed on 2026-11-26: most rules can be automated; about eight need judgement (S1's exceptions, D2's exceptions, new JSON columns, writing events that skip the scope check, logs that may carry personal data, page-local versions of library components, shared components staying app-free, tests reading seeds).
