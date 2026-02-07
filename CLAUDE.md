# CLAUDE.md

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads) for issue tracking. Use `bd` commands instead of markdown TODOs. See AGENTS.md for workflow details.

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
- "The V1 page has X feature - should I port that too?"

## Project Overview

The Quercus Database is a comprehensive database and query tool for oak (Quercus) species and their hybrids.

## V1 to V2 Port (Active)

**We are porting from Go + Svelte (V1) to Elixir + Phoenix LiveView (V2)**, modeled on the `~/dev/gallformers` project. See `docs/plans/2026-02-06-elixir-phoenix-port-design.md` for the full design.

### Critical Rules

- **NEVER modify V1 code** (`api/`, `web/`, `cli/`). It is frozen and will be deleted after cutover.
- **USE V1 as reference** when building V2. Read it freely for features, data flow, API endpoints, and UI behavior.
- **All new work goes in V2 directories** (`lib/`, `config/`, `assets/`, `test/`, `priv/`).
- **The database schema stays the same.** Ecto schemas must match the existing SQLite tables exactly.
- **Model patterns on gallformers** (`~/dev/gallformers`) for Phoenix/LiveView/Ecto conventions.

### V1 Reference Directories (frozen, read-only)

| Directory | Use as reference for |
|-----------|---------------------|
| `api/internal/db/schema/schema.sql` | Database schema / Ecto schema definitions |
| `api/internal/handlers/` | Route handlers / LiveView page logic |
| `web/src/routes/` | Page routes and UI layout |
| `web/src/lib/components/` | UI component design and features |

### V2 Directories (active development)

| Directory | What |
|-----------|------|
| `lib/oak_compendium/` | Business logic contexts (species, taxonomy, sources, etc.) |
| `lib/oak_compendium_web/` | Web layer (LiveViews, controllers, components) |
| `config/` | Phoenix configuration |
| `assets/` | JS, CSS, Tailwind |
| `priv/repo/` | Migrations, structure.sql, seeds |
| `test/` | Elixir tests |

### V2 Tech Stack

- **Framework**: Phoenix 1.8+ with LiveView
- **Database**: SQLite via Ecto + ecto_sqlite3 (same database file)
- **HTTP Server**: Bandit
- **Styling**: Tailwind v4
- **Quality**: Credo, Dialyxir, mix format
- **Deployment**: Fly.io with Litestream (S3 replication)

## Development Commands

```bash
mix setup                  # Install deps, setup DB, build assets
mix phx.server             # Start dev server at http://localhost:4000
mix format                 # Format code
mix credo --strict         # Run code quality checks
mix precommit              # Run all checks before committing
make ci                    # Full CI check (format, compile, credo, test, assets, dialyzer)
```

**CRITICAL: Always compile with `--warnings-as-errors`**. When verifying code changes, NEVER use plain `mix compile` - always use `mix compile --warnings-as-errors` or run `mix precommit`.

## Before Committing

Always run before committing:

```bash
mix precommit    # Runs format, credo, and tests
```

Do not commit until precommit passes.

## Testing

### Test Database

Tests use a **separate test database** (`priv/oak_compendium_test.sqlite`) that is:
- **Schema-only**: Created from `priv/repo/structure.sql`
- **Minimal seed data**: Loaded from `priv/repo/test_seeds.sql`
- **Rebuilt with**: `MIX_ENV=test mix ecto.drop && MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.load` then `sqlite3 priv/oak_compendium_test.sqlite < priv/repo/test_seeds.sql`

**Important**: The `mix test` alias uses `ecto.load --skip-if-loaded`, so it won't reload if the DB exists. After modifying `test_seeds.sql`, you must rebuild manually. Changing seeds can break existing tests that assert counts.

### Running Tests

```bash
mix test                       # Run all tests
mix test test/path/to/test.exs # Run specific test file
mix test test/path:42          # Run specific test at line
```

## Database

- **Schema**: Defined in `api/internal/db/schema/schema.sql` (single source of truth)
- **Local dev**: `oak_compendium.db` (project root, committed for convenience)
- **Production**: Fly.io volume at `/data/oak_compendium.db` (authoritative)
- **Syncing**: Use `make download-db` to pull the latest from Fly.io

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

## Authentication (V2)

- Auth is via API key passed as a LiveView connect param
- Auth check in `handle_params` must guard with `connected?(socket)` before redirecting
- During static render, `get_connect_params` returns nil, so `authenticated` is always false
- Pattern: `if authenticated do ... else if connected?(socket) do redirect else {:noreply, socket} end end`
- GET/read operations are public; write operations require auth

## Git Workflow

**Push approval rules:**
| Change Type | Approval Required | Notes |
|-------------|-------------------|-------|
| Beads (`.beads/`) | No | Daemon auto-syncs via `beads-sync` branch |
| Everything else | **Yes** | Always ask user before pushing |

**Commit messages:** Present tense, imperative mood.

**CRITICAL: Never amend commits.** Always create new commits.

## Fly.io Deployment

- **Region**: Always use `iad` (Ashburn, Virginia)
- **App name**: `oak-compendium-api`
- **Configuration**: `fly.toml` in project root
- See gallformers CLAUDE.md for Fly.io operational rules (same patterns apply)

## Beads Naming

Use component prefixes when creating beads:
- `cli-` for CLI tool issues
- `web-` for web application issues
- `ios-` for iOS app issues

Ask before introducing new prefixes.

## V1 Reference (detailed docs)

For detailed V1 documentation (scraper architecture, CLI commands, Bear app integration, data flow diagrams, API authentication), see `docs/v1-reference.md`. These are rarely needed for V2 development work.
