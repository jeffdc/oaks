# AI Agent Instructions

The instructions for every agent working in this project. The component library is in [docs/COMPONENTS.md](docs/COMPONENTS.md), and the rules the code must follow are in [docs/architecture/rules.md](docs/architecture/rules.md); every agent follows them.

## Work Quality Standards

**CRITICAL**: These standards override any instinct to "move fast" or "show quick progress."

### Investigation Before Action

When fixing bugs, issues, or implementing changes:

1. **STOP** - Do not edit any files yet
2. **Investigate fully** - Find ALL related files, not just the obvious one
3. **Present findings** - Show me what you found and your proposed approach
4. **Wait for approval** - Only proceed after I confirm the approach

### Questions Over Assumptions

If you're unsure about scope, ASK. Examples:
- "I found 3 places this bug could originate - should I investigate all of them?"
- "This fix touches the database - should I also check the related API endpoints?"

## Working rules

**UI work uses the shared component library, always.** Before touching any page, read [docs/COMPONENTS.md](docs/COMPONENTS.md): it says which component to use for each need. Never build a page-local version of a name, width, title row, button, dialog, stamp or anything else the library covers. If the component you need is missing or doesn't fit, stop: add it to the library as its own change for Jeff's review in `/dev/components`, or ask Jeff. An agent that briefs other agents on UI work names the components they must use.

**Dev servers: start them as background tasks and stop them with your stop tool, never with `kill`.** Run `PORT=<port> mix phx.server` (inside the Nix shell) through your shell tool's background option and stop it with the tool that stops background tasks (TaskStop in Claude Code), so stopping needs no approval. For a server left running, `scripts/stop-dev-server <port>` is the one pre-approved fallback: it stops only a Phoenix server on that port. Never touch Jeff's servers on 4444 (his `make dev`) and 4460 (the integration preview); the script refuses them.

**Size the work before starting it** (Jeff, 2026-11-22). Small changes must not take half an hour.
- **Small** (one width, one wording, one component tweak, a few files): make it directly in the integration worktree, where Jeff's preview already runs. Check with `mix precommit` (its tests include the UI rules) and a look at 2 widths on 2 or 3 pages. No worktree setup, no separate reviewer.
- **Medium** (a component rolled out across a few pages): one agent in its own worktree. Impeccable's detector and one look across the affected pages at 2 widths; no separate finish-reviewer agent.
- **Large** (a new page, a redesign, a new visual direction): the full process, including Impeccable's decision page and finish review.
- Don't re-run the hard checks on a fast-forward merge: it is the exact commit that already passed them.
- Keep reports and tours short: what changed, what to look at, what Jeff must decide.

## Before handing work over

- **Hard checks:** `make done-checks`. It rebuilds the checkout's test database, then runs heartwood's `check-toolchain`, `mix precommit` (whose tests include the guardrails), a prod compile with warnings as errors (only it sees a warning from code that differs in prod, such as a `~p` to a `/dev` route), `mix dialyzer` and the security audits (`mix hex.audit`, `mix deps.audit`, `mix sobelow`): everything CI requires. Run it inside the Nix dev shell (direnv, or `nix develop -c make done-checks`). Don't call work finished until it passes.
- **Guardrails** (`Oaks.GuardrailsTest`, in `mix test`): the UI rules (`OaksWeb.Conformance`; docs/COMPONENTS.md), copied code (Credo's `DuplicatedCode`; `mix credo --config-name duplicates` shows each block) and retirements (`test/support/retirements.exs`: a change that replaces a module adds its entry first, as its failing test, and deletes the old module in the same change). Their baselines in `test/support/` only shrink: after a fix, `mix heartwood.baseline <ratchet>` lowers one; never write one to let something new pass. Their code is heartwood's (`heartwood_guardrails`, from `~/dev/heartwood`): a bug in it is fixed there, with oaks pointed at the checkout (`HEARTWOOD_PATH=~/dev/heartwood`), never in `deps/`.
- **Plans** are markdown docs in `docs/` (for example `docs/species-photos-plan.md`), written with Jeff. Don't change a plan's scope or decisions unless Jeff asks.

## Project Overview

The Quercus Database is a comprehensive database and query tool for oak (Quercus) species and their hybrids. Built with Elixir/Phoenix LiveView, modeled on the `~/dev/gallformers` project.

## Project Structure

| Directory | What |
|-----------|------|
| `lib/oaks/` | Business logic contexts (species, taxonomy, sources, etc.) |
| `lib/oaks_web/` | Web layer (LiveViews, controllers, components) |
| `config/` | Phoenix configuration |
| `assets/` | JS, CSS, Tailwind |
| `priv/repo/` | Migrations, seeds |
| `test/` | Elixir tests |

## Tech Stack

- **Framework**: Phoenix 1.8+ with LiveView
- **Database**: SQLite via Ecto + ecto_sqlite3
- **HTTP Server**: Bandit
- **Styling**: Tailwind v4
- **Quality**: Credo, Dialyxir, mix format
- **Deployment**: Fly.io with Litestream (S3 replication)
- **Toolchain**: Nix flake (`flake.nix`, pinned by `flake.lock`, loaded by direnv via `.envrc`) — Elixir/OTP, SQLite, and a pinned Tailwind. CI runs in the same shell and the Dockerfile builder image must match it (heartwood's `check-toolchain`). Mirrors gallformers.

## Development Commands

```bash
mix setup                  # Install deps, setup DB, build assets
mix phx.server             # Start dev server at http://localhost:4444
make dev BRANCH=<name> PORT=<port>  # Dev server for a branch in another worktree (e.g. the integration branch)
mix format                 # Format code
mix credo --strict         # Run code quality checks
mix precommit              # Run all checks before committing
mix smoke_test <url>       # Run smoke tests against a deployment
```

**CRITICAL: Run mix inside the Nix dev shell** (direnv, or `nix develop -c <cmd>`). A Homebrew or other system Elixir is a different version than CI and production, and its formatter can disagree with CI.

**CRITICAL: Always compile with `--warnings-as-errors`**. When verifying code changes, NEVER use plain `mix compile` - always use `mix compile --warnings-as-errors` or run `mix precommit`.

## Before you commit

Run `mix precommit` (format, compile with warnings as errors, Credo, tests) and don't commit until it passes.

The pre-commit hook (`dev/githooks/`, installed by `make hooks`) then blocks a commit without a passing reuse review. A commit touching only prose (`HEARTWOOD_PROSE` in `dev/guardrails/config.sh`: `docs/`, every Markdown file, LICENSE and DATA_LICENSE) needs none, and a pull request that changes only prose skips CI's code jobs.

1. Stage files by name, then run `deps/heartwood_guardrails/guardrails/bin/review-packet`.
2. A reviewer with fresh context, not yours (a different model is better), follows the packet it prints and records its verdict with the packet's `record-review` command.
3. On block: fix, restage, review again. Never re-run the review for a different answer; disputes go to Jeff.
4. Commit once it passes.

The hook also blocks a staged `mix.lock` without heartwood's entries, as `HEARTWOOD_PATH` leaves it: unset it, run `mix deps.get`, and restage `mix.lock`.

## Testing

### Test Database

Tests use a **separate test database** (`priv/oaks_test.sqlite`) that is:
- **Schema**: Built by running the migrations in `priv/repo/migrations`
- **Minimal seed data**: Loaded from `priv/repo/test_seeds.sql`
- **Rebuilt with**: `make test-db` (drops the file, runs `ecto.create` + `ecto.migrate`, then loads the seeds with `sqlite3`)
- **Copied per run**: `priv/oaks_test.sqlite` is a template no test run opens. Each `mix test` runs on its own copy at `_build/test/test_dbs/oaks_test-<pid>.sqlite`, taken at start and deleted at exit (`isolate_test_db/1` in `mix.exs`), so concurrent runs in one checkout, `mix test --partitions`, and `make test-db` during a run don't collide. A run started before `make test-db` keeps its old copy. Don't run two `make test-db` at once in one checkout.

**Important**: The `mix test` alias runs `ecto.migrate` (so new migrations apply automatically) but never reloads seeds. After modifying `test_seeds.sql`, run `make test-db`. Tests never read the seeded rows: each test builds its own data with the fixture modules in `test/support/fixtures/` and asserts only on rows it created (Fixtures, below), so changing the seeds needs no test change.

### Fixtures

Test fixtures live in `test/support/fixtures/`, one module per context: `Oaks.AccountsFixtures`, `Oaks.AnalyticsFixtures`, `Oaks.ArticlesFixtures`, `Oaks.SourcesFixtures`, `Oaks.SpeciesFixtures` and `Oaks.TaxonomyFixtures`. `DataCase` and `ConnCase` don't import them; each test file imports the ones it uses:

```elixir
import Oaks.SourcesFixtures
import Oaks.SpeciesFixtures
```

A fixture merges the attrs it's given over defaults with a unique name (`System.unique_integer([:positive])`) and inserts through the context's create function, so it runs the same changeset production does:

```elixir
defmodule Oaks.SpeciesFixtures do
  def species_fixture(attrs \\ %{}) do
    defaults = %{scientific_name: "species#{System.unique_integer([:positive])}", is_hybrid: false}
    {:ok, species} = defaults |> Map.merge(Map.new(attrs)) |> Oaks.Species.create_species()
    species
  end
end
```

Call fixtures in `setup` or in the test body, never in `setup_all` or a module attribute, so the rows stay inside the test's sandbox transaction. Each test file builds the small world it needs; there is no shared scenario fixture (`taxon_tree_fixture/1` builds a subgenus, section and subsection).

Tests never read the rows in `priv/repo/test_seeds.sql`. Assert only on rows the test created: check membership, compare whole-table numbers with the context's count function (`Species.count()`, `Sources.count()`) or a before/after difference, and use exact counts only within a filter value the test made unique.

### Running Tests

```bash
mix test                       # Run all tests
mix test test/path/to/test.exs # Run specific test file
mix test test/path:42          # Run specific test at line
```

## Database

- **Schema**: Defined only by Ecto migrations in `priv/repo/migrations` (single source of truth). Every schema change is a new migration; there is no `structure.sql` to keep in sync. Production applies pending migrations at startup (`Oaks.Release.migrate/0` from `docker-entrypoint.sh`).
- **Local dev**: `oaks.db` at project root, gitignored. Pull a fresh copy from Fly.io with `make download-db`.
- **Production**: Fly.io volume at `/data/oaks.db` (authoritative)

### Data Sources

| Source | ID | Purpose |
|--------|-----|---------|
| iNaturalist | 1 | Authoritative taxonomy and species list |
| Oaks of the World | 2 | Rich descriptive data (morphology, distribution, local names) |
| Oak Compendium | 3 | Personal observations (preferred for display) |

### Key Design Decisions

- **Source 3 is preferred**: Personal observations take precedence over other sources for display
- **Source attribution**: Every data point is linked to its source via `species_sources` table
- **Fly.io database is the single source of truth**: Local copies are for development only

## SQLite Compatibility

This project uses **SQLite** (via ecto_sqlite3), not PostgreSQL. Always ensure queries are SQLite-compatible:

```elixir
# WRONG - PostgreSQL only
where: ilike(s.name, ^search_term)

# CORRECT - SQLite compatible
search_term = "%#{String.downcase(query)}%"
where: fragment("lower(?) LIKE ?", s.name, ^search_term)
```

## Authentication

- Editors log in with a password and a TOTP code (or a recovery code) at `/users/log-in`; built from `phx.gen.auth` (item 0249). Code: `Oaks.Accounts` (users, Argon2id hashes, encrypted TOTP secrets, hashed tokens and recovery codes) and `OaksWeb.UserAuth` (sessions, plugs, `on_mount`).
- There is no sign-up. `Oaks.Release.setup_link/1` creates a user (or recovers one) and prints a one-time setup link; see its doc for the `fly ssh` command. Any number of users is allowed, and every user can edit.
- Locally, the login page has a "Log in as dev user" button: `POST /dev/log-in` (`OaksWeb.DevLoginController`) logs in as `dev@localhost` with no password or code. Its route is compiled only when `config :oaks, dev_routes: true` (dev and test), so a production release has none.
- Every browser request and LiveView has `@current_scope`: an `Oaks.Accounts.Scope` when logged in, `nil` when not. It is set on the static render too, so LiveViews redirect logged-out visitors straight away (no `connected?/1` check).
- Gate editing UI with `@current_scope`, and re-check `socket.assigns[:current_scope]` in every `handle_event` that writes.
- GET/read pages are public. The JSON API (`/api/v1`) is read-only and unauthenticated. Whether it is served is an architecture decision, not a code decision; the current decision is in [decisions.md](docs/architecture/decisions.md).
- Agents use the private API (`/api/private/v1`, not in the OpenAPI spec) with agent tokens an editor issues and revokes at `/users/settings/api-tokens` (item fbd0). Code: `Oaks.Accounts.ApiToken` (hashed, scoped `materials:read` / `packages:submit`, expiring) and `OaksWeb.Plugs.ApiToken` (Bearer check, rate limits, `require_api_scope/2` for routes that need a scope). Completing setup from a setup link revokes a user's tokens; a password change doesn't.
- Bulk data changes go through the private API's import endpoint (`POST /api/private/v1/import`, `packages:submit`, item f8f5), always dry-run first; see [docs/import.md](docs/import.md).
- Production needs the `LOGIN_ENCRYPTION_KEY` secret (32 bytes, base64; see `config/runtime.exs`). Changing it makes enrolled authenticator apps unusable until a setup link is used.
- Login attempts are rate limited in memory (`OaksWeb.LoginLimiter`), fine for the one app machine.

## Git Workflow

**Push approval rules:**
| Change Type | Approval Required | Notes |
|-------------|-------------------|-------|
| Everything else | **Yes** | Always ask user before pushing |

**Pull requests:** main changes only through pull requests, as in gallformers. Work goes on a branch, the branch is pushed (with Jeff's OK), a PR is opened, and Jeff merges it on GitHub. Don't merge into local main.

**Push guard:** `make hooks` (also run by `make setup`) installs `dev/githooks/pre-push`, heartwood's push guard, which blocks force pushes and pushes to main or master from anyone. Jeff can push main for a one-off with `OAKS_PUSH_MAIN=1 git push ...`; agents never set it.

**Commit messages:** Present tense, imperative mood.

**CRITICAL: Never amend commits.** Always create new commits.

## Fly.io Deployment

- **App**: `oaks` (Phoenix app)
- **Region**: Always use `iad` (Ashburn, Virginia)
- **Configuration**: `fly.toml` in project root
- **Domains**: `oakcompendium.org`, `oakcompendium.com`, and `www.`/`api.` subdomains
- **CI/CD**: Push to `main` triggers CI, successful CI triggers deploy + smoke tests
- See gallformers CLAUDE.md for Fly.io operational rules (same patterns apply)

### The "sleep infinity" pattern for database operations

This is the correct way to perform file operations on a Fly.io machine's volume:

1. Stop machine (if running)
2. Update machine command: `fly machine update <id> --command "sleep infinity" --app oaks`
3. Start machine (now runs `sleep infinity` instead of app — releases DB lock)
4. Perform file operations (backup, upload, verify)
5. Clear command override: `fly machine update <id> --command "" --app oaks`
6. Restart machine (reverts to Dockerfile CMD with fly.toml config)

**Why this works:**
- Machine starts successfully (`sleep infinity` never fails)
- App is not running, so DB lock is released
- Machine keeps all its configuration (memory, health checks, etc.)
- Clearing command override reverts to original Dockerfile CMD
- No machine destruction/recreation needed

**Important:** When updating to `sleep infinity`, the flyctl CLI will appear to hang waiting for a health check that will never pass (the app isn't running, so nothing serves HTTP). This is expected — the machine IS running, flyctl is just waiting. Check `fly machine status <id>` to confirm state is `started`, then kill the stuck flyctl process and proceed with file operations.

## Old item IDs (mull history)

Work used to be tracked in mull, which is retired. Don't run the `mull` CLI, don't create items, and don't add `Mull:` commit trailers or `<id>-` branch names. Cite a commit, PR or plan doc instead.

Old IDs remain throughout code comments, docs, commits and branch names: four hex characters such as "item a44d", "question 96e8" or "matter 16bb". They record why something is the way it is, often in Jeff's words, and are worth reading before changing what they cite. Both stores are read-only history: never edit them.

- **Item, idea, bug, question or decision `<id>`**: a mull record on the `mull` git branch. Read it with git, without checking the branch out:
  - `git ls-tree -r --name-only mull | grep <id>` finds every file for it.
  - `git show mull:items/<id>.md`: an item, idea or bug (title, plan, stage, and the request).
  - `git show mull:reports/<id>-1.md`: its done report (summary, design notes, tour).
  - `git show mull:inbox/<id>.md`: a question or decision and its answer.
  - `git show mull:plans/<slug>.md` and `mull:docs/`: plans and their phase docs.
  - `git log --all --grep "Mull: <id>"`: the commits that did it.
- **Matter `<id>`**: the tracker before mull, in `.mull/matters/<id>-*.md` on main.
