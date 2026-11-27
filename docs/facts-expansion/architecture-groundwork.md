# Architecture groundwork

Phase 4 of the [Facts expansion](README.md). Core architecture work that comes before any other new work (Jeff, 2026-11-26): keys instead of names for links, a decision on JSON in TEXT columns, how code is shared with gallformers, the production toolchain, and what becomes of each manual architecture rule. It starts from the [architecture baseline](../architecture/README.md) and its [first review](../architecture/reviews.md).

Order (Jeff, 2026-11-26): the JSON columns and links by key first; sharing with gallformers was decided in its own discussion, and its step 1 (heartwood's guardrails) comes before the manual rules, which come last. Each decision gets an entry in [decisions.md](../architecture/decisions.md).

## Done when

- Species point at their taxa, taxa at their parent, and species at their parents by foreign key. No code rewrites names to keep links intact. API v1 responses are unchanged.
- The JSON-in-TEXT columns are changed as decided in section 2, and rule D4 has no violations.
- Heartwood exists, and oaks runs on `heartwood_guardrails` and on `heartwood_ui`'s photo viewer (section 3, steps 1 and 2); gallformers' move onto them is in its backlog (step 3).
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

Decided in its own discussion (Jeff, 2026-11-26), with the tooling questions section 5 handed over. Decision: [decisions.md](../architecture/decisions.md).

**Known (2026-11-26):**

- Both apps run Elixir 1.19, OTP 28 and Phoenix LiveView with the same Dockerfile pattern and a Nix flake each, but not the same database: gallformers runs Postgres 17 (main and taxogall), oaks SQLite. Shared code can't touch the database.
- The photo viewer exists in both, and the copies have drifted. Gallformers wrote it first (`photo_viewer/1` in `domain_components.ex`, a 126-line hook, with admin edit links built in); oaks forked it (`OaksWeb.PhotoViewer`, a 187-line hook) and added rail paging, backdrop close and a configurable event. Oaks' version is the app-free one: it depends only on `Phoenix.Component`, and its CSS reads only its own `--pv-*` properties, which `.oc-photos` maps to oaks' tokens.
- Gallformers already has the parts of the fragment-and-reader: `source_entry` and `source_quote` (`domain_components.ex`), `review_reader` (`review_components.ex`) and the ID Notes reader in `gall_live.ex`.
- Of the pure modules the plans port: `PartialDate` (45 lines), `QuoteLocator` (170) and `NameNormalizer` (76) are pure; `Standing` (315) is pure but oaks replaces its newest-wins rule with the lead rule; `Taxa.Ancestry` is an Ecto schema over a Postgres closure table, not pure.
- Gallformers' guardrails are about 1,200 lines that are the same for any app except for their rules, globs and baselines: the conformance ratchet (`conformance.ex`, about half framework and half gallformers' rules), the duplicate-code ratchet (Credo's `DuplicatedCode` against a baseline), retirements, the pre-commit and pre-push hooks, the reuse review's packet and record scripts, and tests for each. Oaks' `scripts/githooks/pre-push` is a copy of gallformers' with no test.
- Both apps' esbuild configs put `deps/` on `NODE_PATH`, both pin Tailwind 4.1.12, both builder images have git, and both repos are public, so a public git dependency needs no credentials in CI or on Fly's builder.

**Decided (Jeff, 2026-11-26):**

- **Heartwood**, a third repo, holds two Mix packages. Each app depends on them as git dependencies pinned by tag, with `sparse:`:
  - `heartwood_ui`, a runtime dependency: the photo viewer, then the fragment-and-reader. Its hooks are plain JS with a `package.json`, imported through `NODE_PATH` as `phoenix_live_view` is; their tests run with vitest in heartwood, so oaks still needs no npm.
  - `heartwood_guardrails`, `only: [:dev, :test], runtime: false`: the ratchet framework (scan, tally per file and rule, a sorted JSON baseline, failure both ways with hints, a test helper and one baseline mix task), the duplicate-code ratchet, retirements, the pre-commit and pre-push hooks, the reuse review's packet and record scripts, the superset `check-toolchain`, and their tests.
- **Each app keeps its own rules:** its conformance rules module (oaks: `OaksWeb.Conformance`, with check-ui's rules and the automated rules from [rules.md](../architecture/rules.md)), its baselines in `test/support/`, its `.credo.exs` duplicates config, its retirements list, the paths the commit gate treats as prose, and its reviewer checklist (heartwood holds the general reviewer text). Each app's hooks are thin scripts that run heartwood's and fail closed, telling you to run `mix deps.get` when `deps/` is missing; `core.hooksPath` never points into `deps/`. The push-main override is one env var name, set per app.
- **Oaks aligns with gallformers' guardrails as far as makes sense:** it adopts the duplicate-code ratchet, retirements, the pre-push hook test and the reuse review with its commit gate, in gallformers' layout (`dev/githooks/`, `dev/guardrails/`). CI runs `check-toolchain` after `mix deps.get`. Gallformers' npm setup and Boundary are not part of this; Boundary is in section 5, and Dialyzer has run in oaks' CI since PR #19.
- **Shared components take each app's design system** as the photo viewer does: their own class prefix (`pv-`, and one for the reader) in plain CSS in `@layer components`, reading only their own custom properties, each with a neutral default; no Tailwind utilities in their markup; `class` for layout only; English labels as attributes with defaults. Each app imports heartwood's CSS and writes one adapter block mapping its tokens (`.oc-photos` in oaks, a `.gf-` block in gallformers, which then gets its dark mode and density for free). App-specific parts stay in each app's wrapper, as `<.species_photos>` does today.
- **Changes flow through heartwood:**
  - Releases are tags, `v0.y.z`, one series for both packages. While it's 0.x, a minor version needs action from an app and a patch is a drop-in. Each app moves to a new tag when it chooses.
  - `sparse:` fetches only a package's folder, so each package carries its own README and `CHANGELOG.md`. Every tag has an entry in the changelog of each package it changes; an entry that needs action has "Upgrade:" steps (rename a custom property in the adapter, pass a new required attribute, rerun the baseline task). Each package's README lists the contract a change has to name if it breaks it: each component's attributes, the events it pushes, the `data-*` attributes its hook reads, its custom properties, the ratchet framework's API and the scripts' flags.
  - Heartwood's AGENTS.md holds the rule: a change is done when it's tagged with its changelog entry, the app that needed it is bumped and its checks pass, and the other app has a backlog entry ("Upgrade heartwood to v0.4: <steps>") or is bumped too.
  - `mix heartwood.status`, in `heartwood_guardrails`, prints the pinned tag, the latest tag (from `git ls-remote`) and a link to the changelog on GitHub. Oaks' architecture reviewer packet (section 5) includes it; gallformers shows it in `done-checks`. It never fails a check.
  - A bug found in an app is fixed in heartwood (the app pointed at a local checkout through a `path:` override set by an env var), then tagged and bumped. Apps never edit `deps/heartwood_*`.
- **Pure domain modules are copied,** as [Sources and facts core](sources-and-facts.md) and [Taxonomy](taxonomy.md) plan: each copy starts with an origin line (gallformers, the path, the commit, what was adapted), and each app owns its copy after that. A bug fixed in one adds a backlog entry in the other. A module moves into heartwood only if it's still the same in both after a while. `Taxa.Ancestry` and the tree validator are rewritten for SQLite with gallformers' as reference.
- **Not shared:** CI workflows (gallformers' jobs need Postgres, npm and the preview app).
- **Heartwood itself** is the public repo `jeffdc/heartwood`, licensed Apache 2.0 (most of its code comes from gallformers, which is Apache 2.0; all of it is Jeff's). It runs its own pre-push hook and commit gate, installed from its source tree, and has its own Nix flake and CI.

**Steps, in order:**

1. **Heartwood's guardrails, and oaks on them.**
   - **1a. Heartwood, tagged `v0.1.0`.** Done 2026-11-26 (heartwood PR #1, tag `v0.1.0`). The repo, created on GitHub with its license and README so that its first code arrives by PR: a flake (Elixir 1.19, OTP 28, Node), CI running format, compile with warnings as errors, Credo and tests per package, a root README and AGENTS.md, and `heartwood_guardrails` in `guardrails/` with its README and CHANGELOG.md. In it:
     - `Heartwood.Guardrails.Ratchet`, the framework half of gallformers' `conformance.ex`. The app passes its rules, globs, exempt files, CSS-only rules and baseline path. A rule is a pattern with a hint and an optional filter (gallformers' "#123 is an issue number, not a colour"), or a counting function for counts that aren't pattern matches (check-ui's `app.css` line budget). With it come a test helper that generates the two-way test, and `mix heartwood.baseline`. Gallformers' rules are its test fixture.
     - The duplicate-code ratchet and retirements, with their paths set by the app. The package depends on Credo `~> 1.7`, as both apps do.
     - The pre-commit and pre-push hooks, the reuse review's packet and record scripts and the general reviewer text. Set by the app: the review folder's name, the paths that count as prose, the push-main env var and the app's reviewer checklist. The commit gate refuses while `HEARTWOOD_PATH` is set, since the local `path:` dependency drops heartwood's entry from `mix.lock`. Gallformers' commit-gate and pre-push tests come with them.
     - The superset `check-toolchain`: every Dockerfile that exists, Typst when the flake provides it, and oaks' `MIX_TAILWIND_PATH` check, with tests.
     - `mix heartwood.status`.
   - **1b. Oaks on `heartwood_guardrails`, one PR.** Not started.
     - `heartwood_guardrails` as a git dependency at `v0.1.0`, or a `path:` dependency when `HEARTWOOD_PATH` is set; `preferred_envs` for `heartwood.baseline`.
     - `OaksWeb.Conformance` with check-ui's rules (page widths, inline styles, daisyUI classes, hand-rolled scientific names, the `app.css` line budget) and a JSON baseline at `check-ui.allow`'s counts. It runs in `mix test`, so in CI.
     - A `.credo.exs` with the `duplicates` config, the duplicate-code baseline, and an empty retirements list.
     - The hooks in `dev/githooks/` and the reviewer checklist in `dev/guardrails/`, the "Before you commit" routine in AGENTS.md, the Makefile's `done-checks` and `hooks` targets, and CI running `check-toolchain` after `mix deps.get`. The commit gate is installed last, so this PR isn't blocked by it.
     - [rules.md](../architecture/rules.md) (U1–U4's checks, O1) and the architecture README's Delivery section change in the same PR.
     - Deletes: `scripts/check-ui`, `scripts/check-ui.allow`, `scripts/check-toolchain`, `scripts/githooks/`.
   - Section 5's rule work builds on this.
2. Move oaks' photo viewer into `heartwood_ui`, with its tests; oaks keeps `<.species_photos>` and `.oc-photos`, and `OaksWeb.PhotoViewer` is deleted.
3. Gallformers moves onto both packages, described in a backlog entry in gallformers' `docs/backlog.md` (taxogall).
4. The fragment-and-reader is built in `heartwood_ui` from the start, with gallformers' ID Notes reader as its design source ([Taxon pages](taxon-pages.md)).

## 4. The production toolchain

**Decided (Jeff, 2026-11-26): keep it.** Production doesn't use Nix: the Dockerfile builds the release in `hexpm/elixir:<elixir>-erlang-<otp>-alpine-<alpine>` and runs it on `alpine`, built by Fly's remote builder. Nix provides the toolchain for dev and CI, and `scripts/check-toolchain` keeps the Dockerfile's versions equal to the flake's. Building the image with Nix would mean leaving Fly's builder for CI, which isn't worth it. Gallformers works the same way.

## 5. The manual rules

After sections 1 and 2 (Jeff, 2026-11-26), and on top of section 3's step 1, which brings in `heartwood_guardrails` and turns check-ui's rules into `OaksWeb.Conformance`.

**Decided (Jeff, 2026-11-26):**

- **Enforcement follows gallformers' conformance-test pattern** in both projects: a scanner module with one rule per pattern (each with a hint naming the right token or component), its own unit tests, a JSON baseline of counts per file and rule, a mix task that updates the baseline, and an ExUnit test that fails when a count goes over its baseline or under it without the baseline being lowered. It runs in `mix test`, so in `precommit` and CI. The framework is in `heartwood_guardrails` (section 3); oaks' rules are in `OaksWeb.Conformance`, starting with check-ui's, and `scripts/check-ui` is retired.
- **One `check-toolchain` for both projects,** in `heartwood_guardrails`: gallformers' loop over every Dockerfile that exists and its Typst check (when the flake provides Typst), plus oaks' `MIX_TAILWIND_PATH` check.
- **Oaks adopts gallformers' other guardrails** through heartwood (section 3): the duplicate-code ratchet, retirements, the pre-push hook test, and the reuse review before each commit with its commit gate.
- **The architecture reviewer** is an assistant Jeff runs periodically, with different models for a mix of opinions. Its first job is finding where new rules are needed and which rules should be automated; judging the manual rules comes second.
  - A prompt in the repo that any model can follow: plain markdown, read-only, nothing specific to one harness.
  - A packet script that gathers the same evidence for every run: the context dependency graph from `mix xref`, every ratchet's output against its baseline, the commits since the last review, `mix heartwood.status` (the pinned heartwood tag against the latest), and the architecture docs. The reviewer starts from the packet and is free to explore beyond it.
  - A report in a fixed shape, with paths and evidence, confirmed in the code: proposed new rules (the pattern, where it occurs, why it matters, how it could be checked); manual rules that could be automated, and how; violations of the manual rules; rules worth retiring; places where the architecture doc no longer matches the code.
  - Reports are kept local, one per model per run. Jeff combines them, with an agent if he likes, into one entry in [reviews.md](../architecture/reviews.md); a finding several models raise independently carries more weight.

**Then, rule by rule:** go through every rule in [rules.md](../architecture/rules.md) whose check is manual or partial, and the gaps and proposed rules in the [baseline review](../architecture/reviews.md), and decide for each: a conformance rule, Boundary (for context dependencies; now Sources and facts core's first step, it may move here), a test that walks the router, a CI change (`deps.unlock --check-unused`; Dialyzer and check-ui already run in CI since PR #19), the reviewer, or retire it. A first triage was discussed on 2026-11-26: most rules can be automated; about eight need judgement (S1's exceptions, D2's exceptions, new JSON columns, writing events that skip the scope check, logs that may carry personal data, page-local versions of library components, shared components staying app-free, tests reading seeds).

**To work out:**

- Where the reviewer prompt and packet script live, and where local reports go (gitignored).
- What "the last review" is for the packet's commit range (the date of the last `reviews.md` entry, or a recorded commit).
- Whether the reviewer prompt and gallformers' code-review port ([gallformers parity](../gallformers-parity-plan.md)) share anything.
