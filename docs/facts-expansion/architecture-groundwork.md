# Architecture groundwork

Phase 4 of the [Facts expansion](README.md). Core architecture work that comes before any other new work (Jeff, 2026-11-26): keys instead of names for links, a decision on JSON in TEXT columns, how code is shared with gallformers, the production toolchain, and what becomes of each manual architecture rule. It starts from the [architecture baseline](../architecture/README.md) and its [first review](../architecture/reviews.md).

Order (Jeff, 2026-11-26): the JSON columns and links by key first; sharing with gallformers was decided in its own discussion, and its step 1 (heartwood's guardrails) comes before the manual rules, which come last. Each decision gets an entry in [decisions.md](../architecture/decisions.md).

## Done when

- Species point at their taxa, taxa at their parent, and species at their parents by foreign key. No code rewrites names to keep links intact. API v1 responses are unchanged.
- The JSON-in-TEXT columns are changed as decided in section 2, and rule D4 has no violations.
- Oaks runs on `heartwood_guardrails` and on `heartwood_ui`'s photo viewer (section 3, steps 1 and 2).
- Every rule in rules.md is automated, covered by the reviewer prompt, or retired; the reviewer prompt exists and has produced a review entry.
- The architecture doc describes the result, and `make done-checks` passes.

## 1. Links by key, not by name

Jeff: links by name are not good and need fixing.

**Known (2026-11-26, dev copy of production):**

- Species point at their taxa by name: `subgenus`, `section`, `subsection` and `complex` match `taxa` by name and level. Taxa point at their parent by name (`taxa.parent`).
- Species point at other species by scientific name: `parent1` and `parent2` (239 species have a `parent1`), and the JSON lists `hybrids`, `closely_related_to` and `subspecies_varieties`.
- Every name link resolves today: no dangling section, subgenus, parent or taxon parent.
- All 478 `hybrids` entries are the reverse of their children's `parent1`/`parent2`: the column is redundant. `subspecies_varieties` is empty in every row. `closely_related_to` is set on one species and is no longer shown (Jeff, 2026-11-25: to be dropped).
- `Oaks.Species.References` keeps the name links intact by rewriting every mention when a species is renamed, deleted or merged; `Oaks.Taxonomy` rewrites `species` rows when a taxon is renamed (an S1 violation). About 20 files read the name fields, among them search, the API controllers and schemas, the species and taxonomy pages, the merge, and `OaksWeb.TaxonPath`.
- API v1 exposes these as names (species' `subgenus`, `section`, …, `parent1`, `parent2`, `hybrids`; taxa's `parent`).

**Decided (Jeff, 2026-11-26):** foreign keys on today's tables, now, rather than bringing Taxonomy's model forward: `taxa.parent_id`; a taxon key on species; `parent1_id` and `parent2_id`; `hybrids` derived by query and its column dropped; `closely_related_to` and `subspecies_varieties` dropped. API v1 keeps its names, computed from the keys. `References` and Taxonomy's species rewrite go away.

**To work out:**

- One key to the lowest taxon, with the ranks above walked through the tree, or a key per rank.
- How a hybrid with an unrecorded parent is stored (today an empty name).
- How the readers of the name fields (search, the merge, the forms, the species and taxonomy pages, `OaksWeb.TaxonPath`, the import endpoint's tables and API v1) switch to keys, with API v1's JSON unchanged.
- The migration: resolving names to keys in a migration, or through the import endpoint with a dry run for Jeff.

## 2. JSON in TEXT columns

**The rule (Jeff, 2026-11-26; rule D4):** JSON in a TEXT column only for a value that belongs to its row, that the database never queries, filters or joins on, and that never points at another row. The app casts it through an embedded schema or a typed array, so it is still validated.

**Decided, column by column (Jeff, 2026-11-26):**

| Column | Holds (2026-11-26) | Decision |
|---|---|---|
| `species.hybrids` | 120 species, names; the reverse of their children's parents | Drop; derive by query (section 1) |
| `species.closely_related_to` | 1 species, names; not shown | Drop |
| `species.subspecies_varieties` | empty | Drop; varieties become child taxa in Taxonomy |
| `species.synonyms` | 426 species, names with authorities; some malformed, including one value that isn't valid JSON | Move to the `names` table |
| `species_sources.local_names` | 359 rows, common names per source; read for the title's common name, the source tabs, search and the API | Move to the `names` table |
| `species.external_links` | 105 species, `{name, source, url, logo}` | Keep as JSON, through one links embedded schema with validated URLs; drop the dead `logo` |
| `taxa.links` | 43 taxa, `{label, url}` | Keep as JSON, through the same embedded schema as species' links |
| `articles.tags` | 1 article; filtered with LIKE on the JSON text | Move to a tags table: cheap, and tags will likely be used more |
| `api_tokens.scopes` | scope strings, in code only | Keep |
| `image_cleanups.paths`, `attempt_ids` | object paths and IDs, read by the cleanup worker only | Keep |

**The `names` table** holds synonyms (with their authority) and common names (with their source), keyed to species for now. It is shaped like the names model the Taxonomy phase plans (accepted, synonym and misapplied names with authorship), so Taxonomy extends it rather than replacing it. The malformed synonyms (listed in [taxonomy.md](taxonomy.md)) are split and cleaned as they move.

**To work out:**

- The `names` columns: kind (scientific synonym, common name), the name, authority, source, language, order, and how a common name marks which one the title uses (today the first nonempty name in the chosen source's list).
- One shared links shape for species and taxa: `{label, url, source}` or similar, and what becomes of species' `name` versus taxa's `label`.
- The tags table: a `tags` table with an `article_tags` join, or tag strings on `article_tags` alone.
- How search, the source tabs, the merge, the forms, the import endpoint's tables and API v1 read the new tables, with API v1's JSON unchanged.
- Whether the moves are migrations or imports through the endpoint with a dry run for Jeff.

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
   - **2c.** Oaks on `heartwood_ui` v0.2.0: the dependency and the two imports. Oaks keeps `<.species_photos>` and `.oc-photos`, with `.oc-photos` mapped to v0.2.0's custom properties. The viewer's filmstrip replaces oaks' paged rail and its step buttons; the 4/5 and 4/3 ratios stay as `.oc-photos` settings. Deleted: `OaksWeb.PhotoViewer`, `assets/js/photo_viewer.js`, the `pv-` block in `components.css` and the tests that moved to heartwood. The dev components page and the docs are updated to match.
3. **The fragment-and-reader** is built in `heartwood_ui` ([Taxon pages](taxon-pages.md)).

## 4. The production toolchain

**Decided (Jeff, 2026-11-26): keep it.** Production doesn't use Nix: the Dockerfile builds the release in `hexpm/elixir:<elixir>-erlang-<otp>-alpine-<alpine>` and runs it on `alpine`, built by Fly's remote builder. Nix provides the toolchain for dev and CI, and `scripts/check-toolchain` keeps the Dockerfile's versions equal to the flake's. Building the image with Nix would mean leaving Fly's builder for CI, which isn't worth it. Gallformers works the same way.

## 5. The manual rules

After sections 1 and 2 (Jeff, 2026-11-26), and on top of section 3's step 1 (oaks on `heartwood_guardrails`).

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
