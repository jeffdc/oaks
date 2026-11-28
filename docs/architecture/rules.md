# Architectural rules

The rules the code must follow, each with its fitness function and its baseline. Every rule here is one Jeff has stated, with its source. Rules a review proposes stay in [reviews.md](reviews.md) until Jeff adopts them; adopting one adds it here and records the decision in [decisions.md](decisions.md). Coding style (naming, docs, idioms) is the formatter's and Credo's, not here. CODING_STANDARDS.md, which some sources below cite, was retired on 2026-11-27: the rules it held are stated here, and its text is in git history.

- **Check** names the automated check and where it runs: local (`make done-checks`), CI, or both. "Manual" means it is checked by hand in reviews until it has a check.
- **Baseline** is the count of known violations at the last review, with where they are. A check holds its rule at the baseline: it fails when the count grows, and the baseline is lowered as violations are fixed.
- IDs are stable and never reused. A retired rule stays, marked retired.

Baselines as of the [2026-11-26 first periodic review](reviews.md#2026-11-26-first-periodic-review).

## Structure

| ID | Rule | Source | Check | Baseline |
|---|---|---|---|---|
| S1 | A context owns its tables. No other module reads or writes them; others call its public functions. | CODING_STANDARDS.md, Phoenix Contexts | Manual | Species and Sources reach into each other: associations both ways (`species/species.ex:37`, `sources/species_source.ex:35`), Species queries `species_sources` (`species.ex:117`), Merge inserts them (`species/merge.ex:308`), Sources queries `species` (`sources.ex:67`). Taxonomy updates `species` rows on a rename (`taxonomy.ex:286`) and reads them: species in a taxon (`taxonomy.ex:169`, `:184`), its usage count (`:318`) and a species-count subquery (`:24`), accepted until the foreign keys land. Search queries Species, Sources and Taxonomy schemas (`search.ex`), counting species per taxon itself (`search.ex:210-219`). The import runner writes Species, Sources and Taxonomy schemas through the Repo (`import/runner.ex`). |
| S2 | The web layer reaches data only through contexts: no `Oaks.Repo` or `Ecto.Query` in `lib/oaks_web`. | CODING_STANDARDS.md, Phoenix Contexts | Manual | 4 files: `analytics_live.ex:79`, `species_source_form_live.ex:96`, `dev_components_live.ex:1032` (dev only), `health_controller.ex:10` (the health ping). |
| S3 | The schema is defined only by migrations; there is no `structure.sql`. | AGENTS.md, Database | Manual | 0 |

## Data

| ID | Rule | Source | Check | Baseline |
|---|---|---|---|---|
| D1 | SQLite only: no `ilike`, and every LIKE has an ESCAPE clause. | AGENTS.md, SQLite Compatibility | Manual | 2 accepted: Ecto `like/2` with a constant pattern and no input (`species.ex:484`, `:496`). |
| D2 | Queries use Ecto's query syntax, not raw SQL. | CODING_STANDARDS.md, Ecto Patterns | Manual | 5: `analytics/rollup.ex` (3: `:64`, `:96`, and a subquery inside a fragment at `:186`; none needed, since the daily tables are already queried through Ecto without schemas), `taxonomy.ex:24` (a `SELECT` over `species` in a module attribute, used as a fragment), `health_controller.ex` (the health ping, accepted). |
| D3 | Data changes go through the app or the import endpoint. An import is dry-run first, and the apply is refused without the dry run's token for the same body. No hand-run SQL against production. | AGENTS.md, Authentication; docs/import.md | Import protocol tests (`private_api/import_controller_test.exs`, `body_digest_test.exs`): both. No SQL over Fly: manual. | 0 |
| D4 | JSON in a TEXT column only for a value that belongs to its row, that the database never queries, filters or joins on, and that never points at another row; the app casts it through an embedded schema or a typed array. | [decisions.md](decisions.md), 2026-11-26 | Manual | 6 columns: `species.hybrids`, `closely_related_to`, `subspecies_varieties` and `synonyms`; `species_sources.local_names`; `articles.tags`. Being fixed in [Architecture groundwork](../facts-expansion/architecture-groundwork.md#2-json-in-text-columns). Links (`species.external_links`, `taxa.links`) are allowed but not yet cast through an embedded schema. Accepted: `image_cleanups.attempt_ids` holds `image_import_attempts` ids that the cleanup worker filters on (`cleanup_worker.ex:54`), because a cleanup outlives its attempts and so can't hold a foreign key. |

## Web and security

| ID | Rule | Source | Check | Baseline |
|---|---|---|---|---|
| W1 | Read pages are public. Editing UI is gated by `@current_scope`, and every `handle_event` that writes re-checks it. | AGENTS.md, Authentication | Forged-event tests on the species page, photos and auth (`species_detail_live_test.exs`, `species_photos_test.exs`, `images_test.exs`, `user_auth_test.exs`): both. Other pages: manual. | Writes: 0 known; every writing handler re-checks the scope. Editing UI: 1, a visitor's forged `show_merge_picker` opens the merge picker (`species_detail_live.ex:150`). Each editor LiveView gates itself; there is no shared guard. |
| W2 | The public API (`/api/v1`) is read-only and unauthenticated. | AGENTS.md, Authentication | Manual | 0: GET routes only. |
| W3 | The private API needs a scoped agent token and is not in the OpenAPI spec. | AGENTS.md, Authentication | Token and scope tests in `private_api/`: both. The spec: manual. | 0. The `materials:read` scope is defined but no route uses it. |
| W4 | No inline scripts or event handlers; scripts load only from the site. | CODING_STANDARDS.md, JavaScript Interop | `content_security_policy_test.exs` (the CSP, and a scan of `lib/oaks_web` for `on*=` handlers and inline `<script>`): both | 0 |
| W5 | Dev-only routes exist only with `dev_routes`. | AGENTS.md, Authentication | `dev_login_controller_test.exs`, `dev_components_live_test.exs`: both | 0 |
| W6 | Never log secrets or personal data. | CODING_STANDARDS.md, Logging | `log_filter_test.exs` covers request params; `user_setup_controller_test.exs` captures the request log at `:info` and checks it holds no setup token: both. Logger calls: manual. | 1: login emails aren't filtered from params (`config/config.exs:109`), logged at `:debug`, so in dev and test only. |
| W7 | Input never becomes an atom; `raw/1` only on sanitized Markdown or component markup. | CODING_STANDARDS.md, Security | Sobelow, high confidence only: both (done-checks; CI on every PR, main and weekly) | 0 `String.to_atom`. 9 `raw(` calls, all on `Oaks.Markdown` output or component internals. |
| W8 | The app makes no LLM calls; agents work through the API. | PRODUCT.md | Manual | 0 |
| W9 | **Retired 2026-11-27.** A change to the public API bumped `API_VERSION`. The public API is off the air while the Facts expansion lands, with no compatibility promise until it returns ([decisions.md](decisions.md), 2026-11-27); the code and its tests stay, and W2 stays true of them. | [decisions.md](decisions.md), 2026-11-26 CI parity; 2026-11-27 | Retired: the API Version Check job is gone. | — |

## UI and design system

| ID | Rule | Source | Check | Baseline |
|---|---|---|---|---|
| U1 | Pages use the component library and never build their own version of something it covers; a missing component is added to the library first. | AGENTS.md, Working rules; docs/COMPONENTS.md | `OaksWeb.Conformance` (page widths, inline styles, daisyUI classes, hand-rolled scientific names), in `mix test`: both | `test/support/conformance_baseline.json`: 1 inline style (`species_compare_live.ex`). Not covered by the conformance test: 6 raw `<button>`s for option and toggle controls the library has no component for (`analytics_live.ex`, `species_compare_live.ex`, `species_detail_live.ex`, `species_merge_live.ex` ×2), 3 `<table>`s in `analytics_live.ex` (the library has `CoreComponents.table/1`); a raw copy button (`user_settings_html/new_api_token.html.heex:13`); inputs and a select hand-built from `oc-input`/`oc-field`/`oc-label` (`species_detail_live.ex:672`, `species_merge_live.ex:430`, `user_session_html/code.html.heex:17`, `user_settings_html/api_tokens.html.heex:36`); a hand-built field (`taxon_form_live.ex:243`); raw checkboxes (`species_merge_live.ex:463`, `api_tokens.html.heex:25`); 3 page-local notices (`species_merge_live.ex:704`, `:728`, `:786`); a hand-copied section heading (`analytics_live.ex:274`). |
| U2 | Page CSS never restyles a library component, and `app.css` only shrinks. | docs/COMPONENTS.md | `OaksWeb.Conformance` line budget for `app.css`, in `mix test`: both. Restyling: manual. | `app.css` 1757 lines, at its budget. 8 selectors in `app.css` restyle `.oc-` classes. Restyled without an `.oc-` selector: `oc-table` through `.analytics-table` (`app.css:828`), native checkboxes beside `.oc-check` (`app.css:505`, `:1511`), and `.oc-flash` by an arbitrary Tailwind variant (`dev_components_live.ex:283`, dev only). |
| U3 | Every page sets its width with `<.page>` and its title row with `<.header>`. | docs/COMPONENTS.md; DESIGN.md | `OaksWeb.Conformance` width rule (page-made widths), in `mix test`: both. Use of `<.page>`/`<.header>`: manual. | 0 pages without `<.page>`. The home page has no `<.header>` (its title page stands in). |
| U4 | Scientific names are set only through `<.sci_name>` (Botanical Italic Rule). | DESIGN.md; docs/COMPONENTS.md | `OaksWeb.Conformance` sci-name rule, in `mix test`: both | 0 |
| U5 | Colours come from the tokens; ochre is the only saturated fill; IUCN colours appear only on Red List stamps. | DESIGN.md | Manual | Hex values outside `tokens.css`: 3 in `app.css` (`#fff`), 45 in `components.css` (IUCN fills, masks, photo viewer defaults). 0 Tailwind palette colour classes. |
| U6 | Square corners; no shadows. | DESIGN.md | Manual | 2 radii (`.merge-spinner`; the focus outline's 1px, `system/base.css:75`), 1 shadow (`.species-row:hover`). 0 `rounded-*` or `shadow-*` classes. |
| U7 | No `@apply`; no external scripts, stylesheets or fonts. | CODING_STANDARDS.md, Phoenix 1.8 Patterns | Manual | 0 |
| U8 | Code shared with gallformers lives in heartwood and has no app-specific dependencies in its markup, script or styles; each app themes it through one adapter block of its own. | docs/species-photos-plan.md, Phase 6; [decisions.md](decisions.md), 2026-11-26 heartwood | By construction: the photo viewer is in heartwood (`Heartwood.UI.PhotoViewer`, since v0.2.0), which can't depend on either app | 0 |

## Delivery

| ID | Rule | Source | Check | Baseline |
|---|---|---|---|---|
| O1 | One toolchain: the Nix flake, which the Dockerfile and CI match. | AGENTS.md, Tech Stack | heartwood's `check-toolchain` (`heartwood_guardrails`; in CI after `mix deps.get`): both | 0 |
| O2 | Work is finished only when the hard checks pass (`make done-checks`), and CI requires the same checks before a PR can merge. | AGENTS.md, Before handing work over; [decisions.md](decisions.md), 2026-11-26 CI parity | `make done-checks` locally; in CI the Phoenix, Assets, Dialyzer and Elixir Security Audit jobs, all required by the `main-no-push` ruleset | 1: `make done-checks` doesn't run the asset build (`mix assets.deploy`) that CI's Assets job does. |
| O3 | Main changes only through pull requests; no force pushes. | AGENTS.md, Git Workflow | GitHub's `main-no-push` ruleset (no direct pushes, deletion or force pushes; the four CI checks required): on GitHub. `dev/githooks/pre-push`, heartwood's push guard: local, per clone (`make hooks`). | 0 |
| O4 | Environment variables are read only in `config/runtime.exs`. | CODING_STANDARDS.md, Configuration | Manual | 4: `config/dev.exs` (2), `config/config.exs` (`MIX_TAILWIND_PATH`), and `mix.exs:99` (`HEARTWOOD_PATH`, accepted: it picks heartwood's checkout before config loads). |

## Tests

| ID | Rule | Source | Check | Baseline |
|---|---|---|---|---|
| T1 | Tests build their own data with fixtures and assert only on rows they made; they never read the seeds. | AGENTS.md, Testing and Fixtures | Manual | 0 `setup_all`. 2 tests read seeded sources by id: `home_live_test.exs:203` (fails without the seeds) and `species_detail_live_test.exs:73` (`source_with_id/1`). |
| T2 | No `Process.sleep` in tests. | CODING_STANDARDS.md, Phoenix 1.8 Patterns | Manual | 0 |

## Checks that exist

Every automated check today, and the rules it holds.

| Check | Runs | Enforces |
|---|---|---|
| `mix format --check-formatted` | local, CI | formatting |
| `mix compile --warnings-as-errors` | local, CI | no warnings (Ecto also rejects interpolated `fragment` strings) |
| `mix credo --strict` (defaults; `.credo.exs` holds only the `duplicates` config) | local, CI | style |
| `mix test` | local, CI | behaviour; the tests named under W1, W3–W6 and D3; the guardrails below |
| `mix dialyzer` | local, CI (Dialyzer job) | types |
| `OaksWeb.Conformance`, in `mix test` (`Oaks.GuardrailsTest`; its baseline only shrinks) | local, CI | U1–U4 |
| Copied code (`Heartwood.Guardrails.DuplicateCode`: Credo's `DuplicatedCode`, mass 40), in `mix test`; baseline 0 | local, CI | no new copied code (no rule yet) |
| Retirements (`test/support/retirements.exs`, empty), in `mix test` | local, CI | a replaced module is deleted in the same change (no rule yet) |
| heartwood's `check-toolchain` | local, CI | O1 |
| `mix assets.deploy` | CI | the bundles build |
| `hex.audit`, `deps.audit`, Sobelow (`--exit high`) | local, CI (every PR, main, weekly) | dependencies; W7 in part |
| `main-no-push` ruleset | GitHub | O2, O3: the four CI checks required; no direct pushes, deletion or force pushes |
| Dependabot (mix, GitHub Actions) and CodeQL (actions, JavaScript, Python) | GitHub | vulnerable dependencies; code scanning alerts |
| `dev/githooks/pre-push` (heartwood's push guard) | local push | O3 |
| `dev/githooks/pre-commit` (heartwood's commit gate: a passing reuse review by a reviewer with fresh context; AGENTS.md, Before you commit) | local commit | reuse (no rule yet) |
| `mix smoke_test` | after each deploy | the production site answers |
| Impeccable's detector | agent sessions (plugin hook) | design anti-patterns, advisory |
| The architecture review (`MIX_ENV=test mix heartwood.architecture`, several models) | Jeff, periodically | the manual rules that need judgement (`dev/guardrails/architecture.md`); proposes new rules and checks |
