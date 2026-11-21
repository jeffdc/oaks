# CLAUDE.md

**Read [AGENTS.md](AGENTS.md) first.** It names this project's plans, hard checks and layers, and holds the mull protocol: plans, work items, the backlog and open questions live in mull, not in markdown or `.mull/`.

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
- **Toolchain**: Nix flake (`flake.nix`, pinned by `flake.lock`, loaded by direnv via `.envrc`) — Elixir/OTP, SQLite, and a pinned Tailwind. CI runs in the same shell and the Dockerfile builder image must match it (`scripts/check-toolchain`). Mirrors gallformers.

## Development Commands

```bash
mix setup                  # Install deps, setup DB, build assets
mix phx.server             # Start dev server at http://localhost:4444
mix format                 # Format code
mix credo --strict         # Run code quality checks
mix precommit              # Run all checks before committing
mix smoke_test <url>       # Run smoke tests against a deployment
```

**CRITICAL: Run mix inside the Nix dev shell** (direnv, or `nix develop -c <cmd>`). A Homebrew or other system Elixir is a different version than CI and production, and its formatter can disagree with CI.

**CRITICAL: Always compile with `--warnings-as-errors`**. When verifying code changes, NEVER use plain `mix compile` - always use `mix compile --warnings-as-errors` or run `mix precommit`.

## Before Committing

Always run before committing:

```bash
mix precommit    # Runs format, credo, and tests
```

Do not commit until precommit passes.

## Testing

### Test Database

Tests use a **separate test database** (`priv/oaks_test.sqlite`) that is:
- **Schema**: Built by running the migrations in `priv/repo/migrations`
- **Minimal seed data**: Loaded from `priv/repo/test_seeds.sql`
- **Rebuilt with**: `make test-db` (drops the file, runs `ecto.create` + `ecto.migrate`, then loads the seeds with `sqlite3`)
- **Copied per run**: `priv/oaks_test.sqlite` is a template no test run opens. Each `mix test` runs on its own copy at `_build/test/test_dbs/oaks_test-<pid>.sqlite`, taken at start and deleted at exit (`isolate_test_db/1` in `mix.exs`), so concurrent runs in one checkout, `mix test --partitions`, and `make test-db` during a run don't collide. A run started before `make test-db` keeps its old copy. Don't run two `make test-db` at once in one checkout.

**Important**: The `mix test` alias runs `ecto.migrate` (so new migrations apply automatically) but never reloads seeds. After modifying `test_seeds.sql`, run `make test-db`. Tests never read the seeded rows: each test builds its own data with the fixture modules in `test/support/fixtures/` and asserts only on rows it created (see CODING_STANDARDS.md, Fixtures), so changing the seeds needs no test change.

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

## Coding Standards

See **[CODING_STANDARDS.md](./CODING_STANDARDS.md)** for comprehensive Elixir/Phoenix conventions. All agents must follow these standards.

## Authentication

- Editors log in with a password and a TOTP code (or a recovery code) at `/users/log-in`; built from `phx.gen.auth` (item 0249). Code: `Oaks.Accounts` (users, Argon2id hashes, encrypted TOTP secrets, hashed tokens and recovery codes) and `OaksWeb.UserAuth` (sessions, plugs, `on_mount`).
- There is no sign-up. `Oaks.Release.setup_link/1` creates a user (or recovers one) and prints a one-time setup link; see its doc for the `fly ssh` command. Any number of users is allowed, and every user can edit.
- Locally, the login page has a "Log in as dev user" button: `POST /dev/log-in` (`OaksWeb.DevLoginController`) logs in as `dev@localhost` with no password or code. Its route is compiled only when `config :oaks, dev_routes: true` (dev and test), so a production release has none.
- Every browser request and LiveView has `@current_scope`: an `Oaks.Accounts.Scope` when logged in, `nil` when not. It is set on the static render too, so LiveViews redirect logged-out visitors straight away (no `connected?/1` check).
- Gate editing UI with `@current_scope`, and re-check `socket.assigns[:current_scope]` in every `handle_event` that writes.
- GET/read pages are public. The JSON API (`/api/v1`) is public and read-only; it has no authentication.
- Agents use the private API (`/api/private/v1`, not in the OpenAPI spec) with agent tokens an editor issues and revokes at `/users/settings/api-tokens` (item fbd0). Code: `Oaks.Accounts.ApiToken` (hashed, scoped `materials:read` / `packages:submit`, expiring) and `OaksWeb.Plugs.ApiToken` (Bearer check, rate limits, `require_api_scope/2` for routes that need a scope). Completing setup from a setup link revokes a user's tokens; a password change doesn't.
- Production needs the `LOGIN_ENCRYPTION_KEY` secret (32 bytes, base64; see `config/runtime.exs`). Changing it makes enrolled authenticator apps unusable until a setup link is used.
- Login attempts are rate limited in memory (`OaksWeb.LoginLimiter`), fine for the one app machine.

## Git Workflow

**Push approval rules:**
| Change Type | Approval Required | Notes |
|-------------|-------------------|-------|
| Everything else | **Yes** | Always ask user before pushing |

**Pull requests:** main changes only through pull requests, as in gallformers. Work goes on a branch, the branch is pushed (with Jeff's OK), a PR is opened, and Jeff merges it on GitHub. Don't merge into local main.

**Push guard:** `make hooks` (also run by `make setup`) installs `scripts/githooks/pre-push`, which blocks force pushes and pushes to main or master from anyone. Jeff can push main for a one-off with `OAKS_PUSH_MAIN=1 git push ...`; agents never set it.

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
