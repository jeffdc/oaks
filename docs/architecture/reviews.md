# Architecture reviews

One entry per periodic review of the code against [README.md](README.md) and [rules.md](rules.md), newest first. A review records what it checked and what it found. Each finding ends in one of: **fix** (work to do, with where it's tracked), **accept** (an exception, with the reason, noted in rules.md), **new rule** (added to rules.md with its check, and a decision in [decisions.md](decisions.md)), or **open** (waiting for Jeff).

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
