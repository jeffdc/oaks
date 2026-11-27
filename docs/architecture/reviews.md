# Architecture reviews

One entry per periodic review of the code against [README.md](README.md) and [rules.md](rules.md), newest first. A review records what it checked and what it found. Each finding ends in one of: **fix** (work to do, with where it's tracked), **accept** (an exception, with the reason, noted in rules.md), **new rule** (added to rules.md with its check, and a decision in [decisions.md](decisions.md)), or **open** (waiting for Jeff).

A review runs with heartwood's architecture reviewer: `MIX_ENV=test mix heartwood.architecture` writes the packet (the commits since this file last changed, the context graph from `mix xref`, every ratchet against its baseline, heartwood's version, oaks' questions in `dev/guardrails/architecture.md`, and these docs), and Jeff gives it to several models. Each records its report in `.git/oaks-architecture/<run>/<model>.md`; Jeff combines them into one entry here, where a finding several models raise carries more weight. Committing the entry starts the next review's range.

## 2026-11-26: First periodic review

Run `2026-11-26-29659fc`, main at 29659fc, with two models: claude-opus-5-5 and gpt-6. The four commits since the baseline only changed docs and moved heartwood to v0.1.1, so this review found what the baseline missed rather than anything new. **(both)** marks a finding both models raised on their own. The baselines in rules.md and the drift in README.md are corrected in the same commit as this entry.

### Rule violations

1. **W6, the setup token in the production logs (both).** A setup link carries its token in the path (`router.ex:156`). Phoenix logs every request path at `:info` (`Plug.Telemetry`, `endpoint.ex:62`), and production logs at `:info`. `filter_parameters` covers params, not paths. Opening the link doesn't use the token up (`user_setup_controller.ex:19-30`), so for its 15 minutes anyone who can read Fly's logs can finish setup. **Fixed** in PR #34 (ac52373): the endpoint doesn't log setup-link requests, and a test captures the log at `:info`. **Open:** should opening the link use up the token? `Oaks.Release.setup_link/1` says "works once", which is true only once setup is finished.
2. **W6, login emails in param logs (both).** `email` isn't in `filter_parameters` (`config/config.exs:109`), and `log_filter_test.exs:23` asserts that it stays visible. Phoenix logs params at `:debug`, so this affects dev and test only. **Fix:** filter `email` and change the test.
3. **W1, a visitor can open editing UI.** `show_merge_picker` sets its state without a scope check (`species_detail_live.ex:150`), so a forged event shows "Make synonym of…" to a logged-out visitor. The merge itself stays guarded. **Fix.**
4. **S1, Taxonomy reads `species` (both)**, beyond its recorded write on a rename: `get_species_in_taxon/1` and `species_directly_in/1` (`taxonomy.ex:169`, `:184`), `taxon_usage/1` (`:318`), and the species-count subquery (`:24`, used at `:79`). Search counts species per taxon itself (`search.ex:210-219`) instead of calling `Taxonomy.taxon_usage/1`. **Accept** until the foreign keys of the [groundwork](../facts-expansion/architecture-groundwork.md#1-links-by-key-not-by-name) land; recorded in S1's baseline.
5. **D2, a different set of raw SQL than recorded (both).** `repo.ex` never held any. Uncounted: the `SELECT … FROM species` in a module attribute at `taxonomy.ex:24` and the subquery inside a fragment at `rollup.ex:186`. That makes five. The rollup doesn't need raw SQL, because it already reads and writes the daily tables through Ecto without schemas (`analytics.ex:138`, `rollup.ex:157`). **Fix:** the rollup's three cases move to Ecto. **Accept:** the health check's `SELECT 1`. Taxonomy's subquery goes with the foreign keys. Recorded in D2's baseline.
6. **D1, two LIKEs without ESCAPE (both)**: `species.ex:484` and `:496`, both with constant patterns and no input. **Accept**, recorded. **Open:** reword D1 to "every LIKE on input has an ESCAPE clause".
7. **D4, `image_cleanups.attempt_ids` points at rows (both).** It holds `image_import_attempts` ids (`images.ex:637`), which the cleanup worker filters on (`cleanup_worker.ex:54`), so it isn't one of the "token scopes and cleanup paths" the 2026-11-26 decision kept. **Accept:** a cleanup outlives its attempts on purpose, so the ids can't be a foreign key. Recorded in D4's baseline.
8. **U1, page-made controls beyond the baseline (both).** **Fix:**
   - a raw copy button, `user_settings_html/new_api_token.html.heex:13`;
   - text inputs and a select hand-built from the `oc-input`, `oc-field` and `oc-label` classes where `<.input>` covers them: `species_detail_live.ex:672-680`, `species_merge_live.ex:430-435`, `user_session_html/code.html.heex:17-23`, `user_settings_html/api_tokens.html.heex:36-41`;
   - a hand-built read-only field, `taxon_form_live.ex:243-248`;
   - three page-local notices, `species_merge_live.ex:704`, `:728`, `:786`, beside the library's `ruled_notice`, `error_notice` and `not_covered_notice`;
   - a hand-copied `<.section_heading>`, `analytics_live.ex:274`;
   - raw checkboxes, `species_merge_live.ex:463` and `api_tokens.html.heex:25`, though the library has `.oc-check`.

   **Open:** the copy button needs a library component or an accepted exception. The baseline review's reason for the analytics tables was wrong: the library has `CoreComponents.table/1` (`core_components.ex:586`).
9. **U2, restyles the `.oc-` count misses.** `.analytics-table` restyles `oc-table` through a second class (`app.css:828-835`). `.settings-check input` and `.merge-source-label input` restyle native checkboxes (`app.css:505-524`, `:1511`). `dev_components_live.ex:283` restyles `.oc-flash` with an arbitrary Tailwind variant (dev only). **Fix**, recorded.
10. **U6, an uncounted radius**: `border-radius: 1px` on the focus outline (`system/base.css:75`). Recorded. **Open:** accept it, or square it.
11. **T1, tests that read the seeds (both).** `species_detail_live_test.exs:73-79` (`source_with_id/1`) returns seeded sources 2 and 3 when they exist. `home_live_test.exs:203-214` fails without the seeds (its fixture takes id 1, which the home page drops as iNaturalist), and checks "Primary" only when seeded source 3 exists. **Fix.**
12. **W9, the API Version Check watches too little.** Its paths are the API controllers and `api_spec.ex` (`.github/workflows/ci.yml:180`). A change to `schemas/api_schemas.ex` or the router's API routes bumps nothing. **Fix:** add both. **Open:** the contexts' `to_map` serializers, which checking responses against the spec covers (Checks to build, 5).
13. **W2, responses that don't match the spec.** The spec declares `synonyms` and `external_links` as arrays of strings (`api_schemas.ex:49`, `:109`), but synonyms can be `{"name": …}` objects (`json_list.ex:82`), and links are objects. Both are returned as stored (`species.ex:629`). **Open:** fix the spec now with an `API_VERSION` bump, or with the move to the `names` table in the [groundwork](../facts-expansion/architecture-groundwork.md#2-json-in-text-columns).
14. **Photo downloads aren't held to iNat's hosts after a redirect.** `download_photo/1` checks only the first URL (`inaturalist.ex:109`). Req then follows redirects unchecked and buffers the whole body. The pixel limit (`storage/variants.ex:64`) applies only after the download. Nothing suggests iNat redirects today. **Fix:** refuse redirects off the photo hosts, and stop reading at a byte budget.
15. **O2, `make done-checks` skips the asset build** that CI runs (`Makefile:88`, `ci.yml:121`). **Fix.**
16. **O4, an uncounted read**: `HEARTWOOD_PATH` in `mix.exs:99`, which the heartwood decision needs. **Accept**, recorded.
17. **Dead code**: `Oaks.Import.Metadata` and its `import_metadata` table are left over from the port. Nothing uses them; only `schema_test.exs:124` touches them. **Fix:** a retirement entry, then delete the module and drop the table.

### Other fixes

Found in the code, but no rule is needed for them: each is a single change, or a rule that already exists.

1. **Search repeats Taxonomy's knowledge of how species link to taxa**: the level-to-field map (`search.ex:221`, `taxonomy.ex:17`), the usage count (`search.ex:210-219`, `taxonomy.ex:318`) and the ancestry walk (`search.ex:226-270`). The foreign keys remove it. **Open:** add it to the [groundwork](../facts-expansion/architecture-groundwork.md#1-links-by-key-not-by-name) plan.
2. **Six "decode a JSON array, or `[]`" functions** (`json_list.ex:58`, `species.ex:752`, `articles.ex:217`, `references.ex:89`, `taxonomy.ex:409`, `taxon_form_live.ex:370`) and **three LIKE escapers** (`species.ex:239`, `articles.ex:240`, `search.ex:276`). **Fix:** one of each, in `JsonList` and a LIKE helper.
3. **The fixed source ids** of iNaturalist (1), Oaks of the World (2) and Oak Compendium (3) are attributes in two places (`species.ex:341-342`, `home_live.ex:25,27`) and literals in tests. **Fix:** functions in `Oaks.Sources`.
4. **No copied module's origin line names the gallformers commit**, which the 2026-11-26 heartwood decision requires (`changeset_helpers.ex:5`, `licenses.ex:11`, `inaturalist.ex:11`, `images.ex:21`, `images/attribution.ex:15`, `storage/images.ex:16`, `storage/s3.ex:17`, `storage/variants.ex:9`, `analytics/rollup.ex:5`). **Fix:** add the commits.
5. **`User.email` and `UserToken.token` aren't redacted** (`accounts/user.ex:15`, `accounts/user_token.ex`), so an `inspect` of a user or token would show them. Nothing inspects one today. **Fix:** `redact: true`.

### Proposed rule

Open: Jeff adopts or rejects it.

1. **What a context adds to a write, the import runs too.** The import calls schema changesets directly, so whatever a context adds on top is copied into `Import.Tables` by hand: `stamp_taxon_content/2` (`import/tables.ex:90`) is Taxonomy's `stamp_content_updated/1` (`taxonomy.ex:301`), and `immutable_on_update` repeats the level rule of `update_taxon/2` (`taxonomy.ex:274`). Every model the facts expansion adds to the import can drift the same way, and nothing fails when it does. Check: a test per importable table that writes the same attrs through the context and through the import and compares the rows. Alternatively, keep such logic in the changesets.

### Checks to build

Open: each is its own change. These five are worth their upkeep:

1. **A pattern ratchet (both)**, on `Heartwood.Guardrails.Patterns` beside `OaksWeb.Conformance`. One module of line patterns holds eight rules at their baselines: S2 (`Repo` or `Ecto.Query` in `lib/oaks_web`); D2 (`Repo.query`, `query!`, and SELECT, FROM, INSERT or DELETE inside fragments and module attributes, migrations excluded); D1; W7; T2; U7; O4; and S3 (no `structure.sql`).
2. **W1 (both).** A generic forged-event test: call every editor LiveView's and LiveComponent's events with `current_scope: nil`, and assert that no rows or Oban jobs change and no editor dialog opens (the way `species_photos_test.exs:353` already works). It would have caught violation 3 and replaces the hand-picked tests.
3. **W2, W3 (both).** A test over `OaksWeb.Router.__routes__/0`: `/api/v1` is GET only; every `/api/private` route needs a token; the spec has no private paths; every live route outside a public allowlist redirects a logged-out visitor; and no route takes a credential as a path parameter, so violation 1 can't come back.
4. **U1, U2 (both).** `Conformance` rules for raw `<button>`, `<table>`, `<form>`, `<input>`, `<select>` and `<dialog>`, and for `oc-` classes on page-made markup, outside the components. A count of `.oc-` selectors in `app.css`.
5. **W2, responses match the spec.** Validate the API tests' responses with OpenApiSpex, using fixtures with object synonyms and links. It would have caught violation 13, and it covers the serializers the API Version Check can't see (violation 12).

Not worth a check, for now:

- **T1:** once its two tests are fixed, loading no seeds into the test template holds the rule with no check at all. **Open**, since it changes `make test-db`.
- **W6:** the setup-token test stays; other log lines are left to the reviews.
- **W9:** a diff of the OpenAPI spec would add little beyond the wider path list and check 5.
- **O2:** fix the Makefile once; the reviews catch drift.

### Doc drift

Fixed in this commit:

- rules.md baselines for S1, D1, D2, D4, W1, W9, U1, U2, U6, O2, O4 and T1 (violations above). W6's row changed with its fix in PR #34.
- README.md, Contexts and Data: the daily analytics tables are written and read through Ecto without schemas (only the rollup's pending-day select and per-day delete use SQL); `import_metadata` is unused; there is no `Oaks.Storage` module; `image_cleanups.attempt_ids` holds row ids; Taxonomy reads species.
- README.md, Web layer: `/settings` is a LiveView that gates itself in mount; only `/users/settings/*` is behind the plug.
- README.md, Delivery: `make done-checks` doesn't run the asset build.

### Not confirmed

1. Whether rolling back a species delete or merge, after the photos have been handed to `Oaks.Images` inside the same transaction (`species.ex:598`, `merge.ex:86`), leaves `image_cleanups` correct. A test that fails the merge after `merge_species_images` would settle it.
2. Whether an import can create species whose parent or taxon names match no row. Reading `import/body.ex` for name checks would settle it.
3. Whether a long-lived LiveView reuses its visitor hash across UTC midnight (`analytics/track_page_view.ex:60`, `:103`). A same-LiveView path change under a controlled clock would settle it.
4. Whether any storage or transport error that `inspect` writes to logs and to `last_error` (`cleanup_worker.ex:102`, `import_worker.ex:351`) carries credentials. Real adapter failures with synthetic markers would settle it.

## 2026-11-26: Baseline

The first review: the whole system was mapped (contexts and their dependencies from `mix xref`, the web layer, runtime and infrastructure, and every existing check) to write README.md and set each rule's baseline. Main at 8539e38.

### Rule violations

Each is counted in its rule's baseline in rules.md. All open: Jeff decides fix or accept.

1. **S1, contexts reach into each other's tables.** Species and Sources form a cycle (associations both ways, each queries the other's table, Merge writes `species_sources`). Taxonomy writes `species` on a rename. Search and the import runner use three contexts' schemas through the Repo. The import runner may be an accepted exception, since it must apply any table's changesets in one transaction.
2. **S2, the web layer calls the Repo** in 4 files. The health check's `SELECT 1` may be accepted; `analytics_live.ex` and `species_source_form_live.ex` would move into their contexts.
3. **D2, raw SQL** in the analytics rollup (its four daily tables have no schemas), `repo.ex` and the health check.
4. **U1, raw `<button>`s** for option and toggle controls (6) and tables in the analytics page (3): the library has no option-button or data-table component.
5. **U2, page CSS restyles library classes**: 8 `.oc-` selectors in `app.css`.
6. **U5 and U6**: 3 raw `#fff` in `app.css`, one rounded spinner and one hover shadow.
7. **O4**: environment variables read in `config/dev.exs` and `config/config.exs`.

### Gaps in the checks

Rules that are stated but held by nothing, or held only locally. Open.

1. **CI runs neither `scripts/check-ui` nor `mix dialyzer`** (O2), so a PR that skips `make done-checks` can break U1–U4 or types and still pass. **Fixed** 2026-11-26 in PR #19 (CI parity).
2. **`mix deps.unlock --unused` in `precommit` can't fail**: it rewrites `mix.lock`. `--check-unused` is the checking form.
3. **Rules at zero that a one-line grep would lock in**: D1 (no `ilike`; LIKE with ESCAPE), W7's `String.to_atom`, W8 (no LLM client), U6's `rounded-*` and `shadow-*` classes, U7, S3, T2, and U5's Tailwind palette colours.
4. **Rules with small baselines that a ratchet like check-ui's would hold**: S2 (4), D2 (4), U2's `.oc-` restyles (8), O4 (3).
5. **S1 has no check.** Boundary (as gallformers uses it) would make `mix compile` enforce declared context dependencies, with today's crossings recorded as exceptions. It is the first step of [Sources and facts core](../facts-expansion/sources-and-facts.md).
6. **The architecture tests use hard-coded lists.** The forged-event tests (W1) and the analytics route audit cover named pages, so a new page or a new writing event isn't caught. No test walks the router to check that `/api/v1` is GET only (W2), that private routes need a token and are absent from the OpenAPI spec (W3), or that editor routes are gated.
7. **The check scripts have no tests.** `CHECK_UI_ROOT` and `CHECK_TOOLCHAIN_ROOT` exist for testing, but nothing uses them, so a broken pattern in check-ui would pass silently. **Fixed** 2026-11-26 in section 3, step 1b of the [groundwork](../facts-expansion/architecture-groundwork.md#3-sharing-with-gallformers): check-ui became `OaksWeb.Conformance`, with its own tests (`test/oaks_web/conformance_test.exs`), and heartwood tests its `check-toolchain` and hooks.
8. **Sobelow fails only on high-confidence findings,** with its CSP, HTTPS and CSRF-route checks ignored. The CSP test covers the CSP.
9. **The pre-push hook is installed per clone** and nothing checks it is; GitHub's branch protection isn't visible from the repo. **Fixed** 2026-11-26: GitHub's `main-no-push` ruleset blocks direct pushes, deletion and force pushes and requires the five CI checks (O3). The hook's own test comes with heartwood (Architecture groundwork, section 3).

### Proposed rules

Patterns the code follows, or assumes, that no doc states. Open: Jeff adopts or rejects each.

1. **Business logic never depends on the web layer.** One crossing today: `Oaks.Release` calls `OaksWeb.Endpoint.url()` (`release.ex:56`). The endpoint also depends at compile time on `Oaks.Storage.Local` for dev image serving.
2. **One machine.** SQLite on one volume, in-memory rate limits and Oban Lite all assume a single machine, but nothing prevents a second (`fly.toml` sets `min_machines_running = 1` and no maximum). DNSCluster is started with no query.
3. **Editor LiveViews sit behind a shared guard.** Every LiveView shares one live session and each editor page gates itself; an `on_mount` guard or a separate live session would catch a page that forgets.
4. **Infrastructure facts live in code.** The Fly volume's size (3GB, set by hand), the machine size and the secret names are in no file; the Litestream bucket and path is written in four places.
5. **Production fails loudly on missing secrets.** `SECRET_KEY_BASE` and `DATABASE_PATH` raise at boot, but a missing `LOGIN_ENCRYPTION_KEY` or images key only warns, so a deploy without them passes health checks and smoke tests.
6. **Something alerts.** Nothing watches disk use, replication lag or errors; no metrics reporter is attached. The volume has filled once before.

### Doc drift

Fix: in CODING_STANDARDS.md.

1. "Layout Wrapping" says LiveView templates begin with `<Layouts.app>`; none do (the layout is set in `lib/oaks_web.ex`).
2. Two examples use `class="badge"`, which check-ui now forbids.
3. It lists Dialyzer as part of `mix precommit`, which doesn't run it.
4. "Use streams for lists" is followed only by the species list.
