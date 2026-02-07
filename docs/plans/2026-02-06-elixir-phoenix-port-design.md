# Elixir/Phoenix Port Design

## Decision

Replace three separate codebases (Go API, Svelte web app, GitHub Pages deployment) with a single Phoenix LiveView application, modeled on the gallformers project.

## What We're Building

- Elixir/Phoenix LiveView — server-rendered, no SPA
- SQLite + Ecto (same database, same schema)
- Litestream for continuous S3 replication
- Tailwind v4 for styling
- Deployed to a new Fly.io app, replacing both the current API and GitHub Pages site
- Simple API key auth initially, structured for Auth0 later
- No images, no scraper port — text-only, same data

## What Stays

- Python scraper (runs independently, outputs JSON)
- SQLite database and its data (Ecto schemas match existing tables)
- Beads for issue tracking

## What Goes Away

- Go API server (`api/`)
- Svelte web app (`web/`)
- Go CLI (`cli/`)
- GitHub Pages deployment
- Separate GitHub Actions for web/API deploy

## Project Structure

```
oaks/
├── lib/
│   ├── oak_compendium/          # Business logic contexts
│   │   ├── species/             # Species queries + schemas
│   │   ├── taxonomy/            # Taxa hierarchy
│   │   ├── sources/             # Source attribution
│   │   ├── articles/            # Articles/content
│   │   └── search/              # Search across entities
│   ├── oak_compendium_web/      # Web layer
│   │   ├── components/          # Reusable LiveView components
│   │   ├── controllers/         # API controllers (JSON)
│   │   ├── live/                # LiveView pages
│   │   └── plugs/               # Auth, rate limiting
│   └── mix/                     # Custom mix tasks (imports)
├── config/                      # Phoenix config (dev/test/prod/runtime)
├── assets/                      # JS, CSS, Tailwind
├── priv/
│   ├── repo/migrations/         # Ecto migrations
│   └── static/                  # Compiled assets
├── test/                        # Tests
├── mix.exs
├── Dockerfile                   # Multi-stage build + Litestream
├── fly.toml                     # New Fly app config
└── scrapers/                    # Python scraper (unchanged)
```

## Database Strategy

The existing SQLite database is used directly — Ecto schemas match the current tables. This is the same approach gallformers uses with its Prisma-managed database.

- Production: opens the existing database file (Litestream restores on deploy)
- Dev/test: `structure.sql` + test seeds, WAL mode, SQL Sandbox
- Future schema changes: proper Ecto migrations against existing data

## LiveView Pages

| Route | LiveView | Purpose |
|---|---|---|
| `/` | `HomeLive` | Landing page |
| `/list` | `SpeciesListLive` | Browse all species |
| `/species/:name` | `SpeciesDetailLive` | Full species detail with sources |
| `/species/:name/merge/:target` | `SpeciesMergeLive` | Admin merge tool |
| `/compare/:name` | `SpeciesCompareLive` | Side-by-side comparison |
| `/taxonomy` | `TaxonomyLive` | Taxonomy tree browser |
| `/taxonomy/*path` | `TaxonomyLive` | Drill into subgenus/section/etc. |
| `/articles` | `ArticlesLive` | Article list |
| `/articles/:slug` | `ArticleLive` | Single article |
| `/sources` | `SourcesLive` | Source list |
| `/sources/:id` | `SourceDetailLive` | Source detail |
| `/search` | `SearchLive` | Unified search |
| `/settings` | `SettingsLive` | User preferences |
| `/about` | `AboutLive` | About page |

Plus: `/health` (controller), `/api/v1/*` (JSON API), `/api/docs` (OpenAPI).

Admin features (merge, article editing, species CRUD) gate behind API key auth.

## Infrastructure

- **Fly.io app:** new app (e.g. `oak-compendium`), region `iad`
- **Dockerfile:** multi-stage (hexpm/elixir builder + alpine runtime + Litestream)
- **Entrypoint:** restore from Litestream, pre-migration backup, run migrations, start with replication
- **S3 bucket:** `oak-compendium-backups` for Litestream
- **CI/CD:** single GitHub Actions workflow — format, compile (warnings-as-errors), credo, tests, deploy

## Implementation Phases

### Phase 1 — Scaffold & Database
- `mix phx.new` at project root
- Dependencies (ecto_sqlite3, tailwind, credo, etc.)
- Config files modeled on gallformers
- Ecto schemas matching existing tables
- `structure.sql` + test seeds
- Verify we can open and query the existing database

### Phase 2 — Core Read-Only Pages
- Router, layouts, basic Tailwind styling
- Species list + detail pages
- Taxonomy browser
- Sources list + detail
- Search
- About page

### Phase 3 — Content & Admin
- Articles (list, detail, create/edit)
- Species CRUD (new, edit, delete)
- Species merge tool
- Species comparison
- Settings page
- API key auth gating write operations

### Phase 4 — API Layer
- JSON API controllers for `/api/v1/*`
- OpenAPI docs
- Health endpoint

### Phase 5 — Infrastructure & Cutover
- Dockerfile + entrypoint + Litestream
- S3 bucket for backups
- New Fly.io app
- CI/CD workflows
- DNS cutover, retire old API + GitHub Pages

### Phase 6 — Cleanup
- Remove old `api/`, `web/`, `cli/` directories
- Update CLAUDE.md, README
- Update beads/openspec references

## Reference

This design is modeled on the gallformers project (`~/dev/gallformers`), which was ported from Next.js/TypeScript to Elixir/Phoenix. Key patterns to reuse:

- Dockerfile + docker-entrypoint.sh (Litestream integration)
- Config structure (dev/test/prod/runtime)
- Ecto + SQLite patterns (WAL mode, fragment-based queries)
- LiveView component architecture
- CI workflow (precommit checks)
- Testing infrastructure (SQL Sandbox, structure.sql + seeds)
