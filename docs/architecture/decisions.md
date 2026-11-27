# Architecture decisions

Jeff's decisions that shape the system's architecture and design, newest first. Each entry says what was decided, why, and what it changes: the parts of [README.md](README.md) it shapes and the [rules](rules.md) it adds or changes. A decision is never edited after the fact; a later decision supersedes it and says so, and the old entry gains a "Superseded by" line.

Entries before 2026-11-26 were recorded when this log began, from the code, its history and the plan docs; their dates are when the decision landed.

Template:

```
## YYYY-MM-DD: <the decision, as a sentence>

- **Why:** …
- **Changes:** … (README sections, rules added or changed)
- **Source:** commit, PR or plan doc
```

## 2026-11-26: CI parity across oaks, gallformers and heartwood

- **Why:** CI enforced less than the local hard checks (no check-ui, no Dialyzer), the rules of the three repos had drifted apart, and CodeQL flagged a cache-poisoning risk in the deploy workflow (rated high).
- **Changes:** the three repos share one CI shape: `mix precommit`, a Dialyzer job, the security audit (hex.audit, deps.audit, Sobelow) on every PR, main and weekly, Dependabot, CodeQL, read-only workflow tokens, and a ruleset on main requiring every check. Oaks adds check-ui to CI and an API Version Check (rule W9: a public API change bumps `API_VERSION`); `make done-checks` runs the audits too (rule O2). In gallformers the security audit runs but isn't yet required, until Earmark and its other vulnerable dependencies are fixed. Deploys: a deploy run restores the dependency cache without saving it, and a manual deploy runs only from main.
- **Source:** Jeff, 2026-11-26; oaks PRs #19 and #26.

## 2026-11-26: Share UI components and guardrails with gallformers through heartwood; copy domain modules

- **Why:** the photo viewer already exists twice, and the copies have drifted: gallformers wrote it first and oaks forked it with rail paging, backdrop close and a configurable event. The guardrails (the conformance ratchet, the duplicate-code ratchet, retirements, the git hooks and their tests, `check-toolchain`) are about 1,200 lines that are the same in both apps except for each app's rules and baselines. Pure domain modules are different: oaks adapts them on purpose (the lead rule in place of newest-wins; SQLite, where gallformers runs Postgres), so sharing them would mean constant overrides.
- **Changes:**
  - A third repo, `heartwood`, holds two Mix packages, each a git dependency pinned by tag and pulled with `sparse:`: `heartwood_ui` (runtime: the photo viewer, then the fragment-and-reader) and `heartwood_guardrails` (`only: [:dev, :test], runtime: false`: the ratchet framework, the duplicate-code ratchet, retirements, the hooks, the reuse review's packet and record scripts, the superset `check-toolchain`, and their tests). Each app keeps its own rules, baselines, `.credo.exs` duplicates config, retirements list, prose paths for the commit gate and reviewer checklist.
  - Oaks aligns with gallformers' guardrails as far as makes sense: it adopts the duplicate-code ratchet, retirements, the pre-push hook test and the reuse review with its commit gate, in gallformers' layout (`dev/githooks/`, `dev/guardrails/`, baselines in `test/support/`).
  - Shared components keep the 2026-11-25 shape, which stands: their own class prefix and custom properties with neutral defaults, no Tailwind utilities in their markup, `class` for layout only, and one adapter block per app mapping its tokens (`.oc-photos` in oaks).
  - Changes flow through heartwood: tagged releases with a `CHANGELOG.md` entry whose "Upgrade:" steps say what an app must do; the change is done when the app that needed it is bumped and the other app has a backlog entry; `mix heartwood.status` shows each app's pinned tag against the latest, for information only. Apps never edit `deps/heartwood_*`.
  - Gallformers' pure modules are copied into oaks with an origin line (repo, path, commit, what was adapted); each app owns its copy. `Taxa.Ancestry` is rewritten for SQLite. CI workflows aren't shared.
  - Rule U8 changes: shared code lives in heartwood, which cannot depend on either app.
- **Source:** Jeff, 2026-11-26; [Architecture groundwork](../facts-expansion/architecture-groundwork.md#3-sharing-with-gallformers).

## 2026-11-26: Enforce rules with conformance tests, as gallformers does

- **Why:** oaks re-invented checks gallformers already had. Gallformers' conformance test runs in `mix test` (so in CI), tests its own scanner and explains each failure; oaks' `scripts/check-ui` does none of these.
- **Changes:** both projects use one ratchet pattern: a scanner with rules and hints, a JSON baseline per file and rule, a mix task to update it, and a test that fails both ways. Oaks' check-ui rules move into it and the script is retired; automated rules from [rules.md](rules.md) join it. One `scripts/check-toolchain` serves both. How the shared pieces are shared is decided with the sharing of code between the two apps.
- **Source:** Jeff, 2026-11-26; [Architecture groundwork](../facts-expansion/architecture-groundwork.md#5-the-manual-rules).

## 2026-11-26: A model-agnostic architecture reviewer, run periodically with several models

- **Why:** most of the value of a review is finding what no rule covers yet and which rules should be automated. Different models notice different things.
- **Changes:** a prompt any model can follow and a packet script that gives every run the same evidence, with freedom to explore beyond it. Reports stay local; Jeff combines them into one [reviews.md](reviews.md) entry per review.
- **Source:** Jeff, 2026-11-26; [Architecture groundwork](../facts-expansion/architecture-groundwork.md#5-the-manual-rules).

## 2026-11-26: JSON in TEXT columns only for opaque values of their own row

- **Why:** names, common names and tags were stored as JSON text and then searched with LIKE, links to other rows were stored as JSON name lists, and nothing validated their contents (one synonyms value isn't valid JSON).
- **Changes:** rule D4. Synonyms and common names move to one `names` table, shaped like the Taxonomy phase's names model; tags move to a table; `hybrids`, `closely_related_to` and `subspecies_varieties` are dropped. Links stay JSON, through one validated embedded schema for species and taxa. Token scopes and cleanup paths stay. To be built in [Architecture groundwork](../facts-expansion/architecture-groundwork.md#2-json-in-text-columns).
- **Source:** Jeff, 2026-11-26.

## 2026-11-26: Link species and taxa by foreign key on today's tables

- **Why:** species point at their taxa and at their parents, and taxa at their parents, by name. Keeping those links intact needs code that rewrites names across rows on every rename, delete and merge, and nothing in the database stops a dangling name.
- **Changes:** to be built in [Architecture groundwork](../facts-expansion/architecture-groundwork.md#1-links-by-key-not-by-name), before Taxonomy, on the existing `species` and `taxa` tables. The redundant `hybrids` list goes; API v1 keeps its names.
- **Source:** Jeff, 2026-11-26.

## 2026-11-26: Keep the production toolchain: Docker on Fly's builder, Nix for dev and CI

- **Why:** building the production image with Nix would give one toolchain definition, but means leaving Fly's remote builder for CI; not worth it. `scripts/check-toolchain` already catches drift between the flake and the Dockerfile.
- **Changes:** none; rule O1 stands.
- **Source:** Jeff, 2026-11-26.

## 2026-11-26: Keep an architecture baseline, and turn violations into checks

- **Why:** the system's shape lived in agents' heads and scattered docs, and rules drifted without anyone noticing. A baseline to review against, and checks that hold each rule at its baseline, keep it from drifting further.
- **Changes:** this folder. Rules start at their 2026-11-26 baselines; periodic reviews go in [reviews.md](reviews.md).
- **Source:** this doc.

## 2026-11-25: Share UI components with gallformers as self-contained pieces

- **Why:** both apps need the same photo viewer (and later the fragment-and-reader), and maintaining two copies drifts.
- **Changes:** the photo viewer is a function component plus one self-contained hook and its own CSS, themed by custom properties, with no app-specific dependencies (rule U8). Pages reach it through an app wrapper (`<.species_photos>`).
- **Source:** docs/species-photos-plan.md, Phase 6; d81986d.

## 2026-11-24: Run durable background work on Oban, in the app's SQLite database

- **Why:** photo imports and storage cleanups must survive restarts and retry without duplicating work; a running Task is not a record of outstanding work.
- **Changes:** Oban with the Lite engine on `Oaks.Repo`; work is persisted as rows (import attempts, cleanups) and a recovery worker re-enqueues it at boot and every 15 minutes.
- **Source:** docs/species-photos-plan.md, Phase 3; 5b8ca89.

## 2026-11-24: Store photos in a private S3 bucket served by CloudFront, behind a storage adapter

- **Why:** photos need durable storage and fast delivery on the site's own domain, and dev and tests must work without AWS.
- **Changes:** bucket `oaks-images` (private, versioned, deleted versions kept 30 days) read only by CloudFront through Origin Access Control, on `images.oakcompendium.org`. Every import attempt writes to unique paths; removal deletes the files and invalidates their paths. `Oaks.Storage` hides the backend: S3 in prod, local disk in dev, a mock in tests. Only photos from iNat observations; no uploads.
- **Source:** docs/species-photos-plan.md, Decisions and Phases 1–2; faf72f6.

## 2026-11-24: Describe AWS in OpenTofu; keep Fly in fly.toml and fly secrets

- **Why:** AWS resources were made by hand and undocumented; the Fly provider added little over `fly.toml`.
- **Changes:** `infra/` describes every AWS resource, state in S3 `oaks-terraform-state`. Access key secrets stay out of tofu state.
- **Source:** docs/species-photos-plan.md, Phase 0; 3f7b9b6.

## 2026-11-23: The design system and component library are the only UI layer

- **Why:** parallel page agents each solved shared problems their own way, and the site looked janky.
- **Changes:** daisyUI and the old CSS layer removed (f874344). Every page is built from the component library; a missing component is added to the library first, reviewed in `/dev/components`. `scripts/check-ui` enforces part of it (rules U1–U4).
- **Source:** AGENTS.md, Working rules; CODING_STANDARDS.md, Components; 71b102f, 513d1ec.

## 2026-11-21: All bulk data changes go through one import endpoint, dry run first; no audit log

- **Why:** changes had been pushed to SQLite by hand-run SQL. An audit log and undo were considered and dropped: the need was only that changes not bypass the app.
- **Changes:** `POST /api/private/v1/import`: JSON shaped like the data model, applied in one transaction or not at all, refused without the dry run's token for the same body (rule D3). Each new model adds its tables to it.
- **Source:** docs/import.md; b4e35e3.

## 2026-11-21: Editors log in with a password and TOTP; agents use scoped tokens; reads stay public

- **Why:** the shared API key in the browser's localStorage was weak and couldn't distinguish people from agents.
- **Changes:** login built from `phx.gen.auth` with TOTP or recovery codes, no sign-up, every user an editor; `@current_scope` on every request (rule W1). Agent tokens with scopes for the private API (W3). The public API stays read-only and unauthenticated (W2).
- **Source:** AGENTS.md, Authentication; b4e3ace, ee001c9.

## 2026-11-21: Tests build their own data

- **Why:** tests that depended on seed counts broke whenever the seeds changed.
- **Changes:** fixture modules in `test/support/fixtures/`; tests assert only on rows they made (rule T1). Each test run uses its own copy of the template test database.
- **Source:** AGENTS.md, Testing; d9afb01, 4fc6571.

## 2026-11-02: Pin the toolchain with a Nix flake shared by dev, CI and the Dockerfile

- **Why:** a system Elixir formatted differently from CI and production.
- **Changes:** `flake.nix` and `flake.lock`; `scripts/check-toolchain` holds the Dockerfile and config to it (rule O1).
- **Source:** e2cc220.

## 2026-11-02: Migrations are the only schema definition; production migrates at boot

- **Why:** `structure.sql` and the migrations disagreed. Fly's release command runs against a volume snapshot whose changes don't persist.
- **Changes:** `structure.sql` dropped (rule S3). The entrypoint backs up and migrates only when migrations are pending, keeping three backups.
- **Source:** f6f0bbc, 40447f2.

## 2026-11-02: Sanitize rendered Markdown and send a strict Content Security Policy

- **Why:** stored content could run script.
- **Changes:** MDEx output sanitized in `Oaks.Markdown`; CSP with `script-src 'self'`, no inline scripts or handlers (rules W4, W7). Extended to error pages on 2026-11-23 (f58fffe).
- **Source:** 6d60022.

## 2026-02-08: One Phoenix LiveView monolith on SQLite, on one Fly machine, replicated by Litestream

- **Why:** the Go and Svelte app was ported to the stack gallformers uses, and the data is small enough for SQLite.
- **Changes:** Elixir and Phoenix LiveView with Bandit; SQLite through `ecto_sqlite3`; one Fly.io machine in `iad` with a volume; Litestream streaming the database to S3. Business logic in contexts that own their tables (rules S1, S2).
- **Source:** 8d26019, e86fa88, 758887e; CODING_STANDARDS.md.
