# CLAUDE.md

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

**Important**: The `mix test` alias runs `ecto.migrate` (so new migrations apply automatically) but never reloads seeds. After modifying `test_seeds.sql`, run `make test-db`. Changing seeds can break existing tests that assert counts.

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

- Auth is via API key passed as a LiveView connect param
- Auth check in `handle_params` must guard with `connected?(socket)` before redirecting
- During static render, `get_connect_params` returns nil, so `authenticated` is always false
- Pattern: `if authenticated do ... else if connected?(socket) do redirect else {:noreply, socket} end end`
- GET/read operations are public; write operations require auth

## Git Workflow

**Push approval rules:**
| Change Type | Approval Required | Notes |
|-------------|-------------------|-------|
| Everything else | **Yes** | Always ask user before pushing |

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
