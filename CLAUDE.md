<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads) for issue tracking. Use `bd` commands instead of markdown TODOs. See AGENTS.md for workflow details.

## Project Overview

The Quercus Database is a comprehensive database and query tool for oak (Quercus) species and their hybrids. The project consists of five main components:

1. **Python Scraper** - Extracts oak species data from oaksoftheworld.fr
2. **Web Application** - Modern Svelte 5 app for browsing and editing species data
3. **API Server** - Go REST API for remote database access (deployed to Fly.io)
4. **CLI Tool** - Go command-line tool for managing taxonomic data (local or remote)
5. **iOS App** - Native SwiftUI app for field identification (in development, on `ios-app` branch)

## Repository Structure

```
oaks/
├── Makefile                  # Top-level dev commands (make dev, make build, etc.)
├── scrapers/oaksoftheworld/  # Python web scraper
│   ├── scraper.py            # Main scraper orchestration
│   ├── name_parser.py        # Parses species list (liste.htm)
│   ├── parser.py             # Parses individual species pages
│   ├── utils.py              # Caching, progress tracking, HTTP utilities
│   └── requirements.txt      # beautifulsoup4, requests, lxml
├── web/                      # Svelte 5 PWA (see web/CLAUDE.md for details)
│   ├── src/                  # Svelte components and stores
│   └── package.json          # Vite, Svelte 5, Tailwind 4
├── api/                      # Go API server (standalone)
│   ├── main.go               # Server entry point
│   ├── internal/             # Internal packages (handlers, db, models, export)
│   ├── go.mod                # Separate Go module
│   ├── Makefile              # Build, lint, test, docker targets
│   └── Dockerfile            # Container deployment
├── cli/                      # Go CLI tool
│   ├── cmd/                  # Cobra command implementations
│   ├── internal/             # Internal packages
│   │   ├── client/           # HTTP client for API (used by all commands)
│   │   ├── config/           # Profile configuration management
│   │   ├── embedded/         # Embedded API server wrapper
│   │   └── models/           # Data structures
│   ├── go.mod                # cobra, yaml.v3
│   ├── Makefile              # Build, lint, test targets
│   └── docs/oak_cli.md       # CLI specification (historical)
├── ios/                      # iOS app (SwiftUI, on ios-app branch)
│   └── OakCompendium/        # Xcode project
└── tmp/                      # Temporary/working files (gitignored)
    ├── scraper/              # Scraper cache and progress files
    └── data/                 # Working data files (e.g., iNaturalist imports)
```

## Common Development Tasks

### Full Stack Development (Recommended)

The top-level Makefile coordinates all components:

```bash
# Start both API server (:8080) and web dev server (:5173)
# Web app automatically connects to local API
# Ctrl+C kills both
make dev

# Or run individually
make dev-api    # API server only
make dev-web    # Web dev server (connects to local API)

# Other useful targets
make build      # Build all components
make test       # Run all tests
make clean      # Clean all build artifacts
make help       # Show all targets
```

### Python Scraper Workflow

```bash
# Navigate to scraper directory
cd scrapers/oaksoftheworld

# Install dependencies (use venv from root)
source ../../venv/bin/activate  # On macOS/Linux
pip install -r requirements.txt

# Run scraper (auto-resumes from last position)
python3 scraper.py

# Force restart from beginning
python3 scraper.py --restart

# Test mode (first 50 species)
python3 scraper.py --test

# Process specific number
python3 scraper.py --limit=10

# Output location: ../../tmp/scraper/quercus_data.json
# Import to database with: cd ../../cli && oak import-oaksoftheworld ../tmp/scraper/quercus_data.json
```

### Web Application Workflow

```bash
cd web

# Install dependencies
npm install

# Development server (http://localhost:5173)
npm run dev          # Uses production API (api.oakcompendium.com)
npm run dev:local    # Uses local API (localhost:8080)

# Production build
npm run build      # Output: dist/
npm run preview    # Preview production build
```

**Note**: Prefer `make dev` from the project root to run both API and web together. The `dev:local` script is useful if you're only working on the web app and the API is already running.

**Important**: The web app fetches data directly from the API (stateless fetch-per-view architecture). No static JSON files or client-side data storage. GitHub Actions deploys automatically on push to main. See `web/CLAUDE.md` for detailed architecture.

### CLI Tool Workflow

```bash
cd cli

# Build
make build       # or: go build -o oak .

# Run directly (ALWAYS from cli/ directory)
./oak <subcommand>

# Or run with go
go run . <subcommand>

# Install to $GOPATH/bin
go install .
```

**Makefile Targets** (run from `cli/` directory):
- `make build` - Build the oak binary
- `make lint` - Run golangci-lint
- `make test` - Run tests
- `make test-coverage` - Run tests with HTML coverage report
- `make check` - Run lint + test
- `make clean` - Remove build artifacts
- `make setup` - Install dev tools (golangci-lint, goimports)

**Local vs Remote Mode**:
- By default, the CLI operates on the local SQLite database
- Use `--profile <name>` to connect to a remote API server
- Use `--local` to force local mode (ignore any configured profile)
- Use `--remote` to force remote mode (errors if no profile configured)

See `cli/README.md` for profile configuration and remote mode details.

**IMPORTANT: Database Location**
- **The authoritative database is hosted on Fly.io** at `/data/oak_compendium.db`
- The local copy at `oak_compendium.db` (project root) is for development/testing only
- Use `make download-db` from the project root to sync the latest from Fly.io
- Run `oak` commands from the project root, or use `-d` to specify the database path

### API Server Workflow

```bash
cd api

# Build
make build       # Produces: oak-api binary

# Run locally (uses ../oak_compendium.db by default)
make run

# Or configure with environment variables
OAK_DB_PATH=../oak_compendium.db OAK_PORT=8080 ./oak-api

# Docker build
make docker-build
```

**Makefile Targets** (run from `api/` directory):
- `make build` - Build the oak-api binary
- `make run` - Build and run locally
- `make lint` - Run golangci-lint
- `make test` - Run tests
- `make test-coverage` - Run tests with HTML coverage report
- `make docker-build` - Build Docker image
- `make clean` - Remove build artifacts

**Environment Variables**:
- `OAK_DB_PATH` - Path to SQLite database (default: `./oak_compendium.db`)
- `OAK_PORT` - HTTP port (default: `8080`)
- `OAK_API_KEY` - API key (or auto-reads from `~/.oak/api_key`)

## Data Flow Architecture

The complete data pipeline from sources to clients:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  iNaturalist            Oaks of the World         Bear App          │
│  (Source 1)             (Source 2)                (Source 3)        │
│  taxonomy + species     descriptive data          personal notes    │
│         │                      │                       │            │
│         ▼                      ▼                       │            │
│  cli/data/*.yaml        scrapers/                     │            │
│         │               oaksoftheworld/               │            │
│         │                      │                       │            │
└─────────┼──────────────────────┼───────────────────────┼────────────┘
          │                      │                       │
          ▼                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    CLI TOOL (oak) - LOCAL MODE                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  oak taxa import        oak import-           oak import-bear       │
│  oak import-bulk        oaksoftheworld        (reads Bear SQLite)   │
│         │                      │                       │            │
│         └──────────────────────┴───────────────────────┘            │
│                                │                                    │
│                                ▼                                    │
│                    oak_compendium.db (SQLite, project root)         │
│                    (see api/internal/db/schema/schema.sql)          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    API Server + CLI Remote Mode                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  API Server (api/)               CLI Remote Mode                    │
│  ├── Deployed to Fly.io          ├── oak --profile prod             │
│  ├── Reads SQLite DB             ├── Uses REST API                  │
│  └── Serves REST API             └── For remote operations          │
│                                                                     │
│  /api/v1/species                                                    │
│  /api/v1/species/{name}/full  (with embedded sources)               │
│  /api/v1/taxa                                                       │
│  /api/v1/sources                                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 │  HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      WEB APP + DEPLOYMENT                           │
├─────────────────────────────────────────────────────────────────────┤
│  Web App: Svelte (fetch-per-view, no client persistence)            │
│  Deployment: git push → GitHub Actions → GitHub Pages               │
└─────────────────────────────────────────────────────────────────────┘
```

### CLI↔API Architecture

The CLI uses an HTTP API client for all operations. In local/embedded mode, it starts an in-process API server. In remote mode, it connects to a standalone API server.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLI (cli/)                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌─────────────────────────────────────────────┐│
│  │ cmd/        │───▶│           internal/client/                  ││
│  │ (commands)  │    │        (HTTP client for API)                ││
│  └─────────────┘    └───────────┬───────────────────────────────┬─┘│
│                                 │                               │  │
│                                 │                               │  │
│                    ┌────────────▼────────────┐                  │  │
│                    │   Embedded Mode         │                  │  │
│                    │   (default, --local)    │                  │  │
│                    │                         │                  │  │
│                    │  ┌───────────────────┐  │                  │  │
│                    │  │ internal/embedded │  │                  │  │
│                    │  │ (in-process API)  │  │                  │  │
│                    │  └─────────┬─────────┘  │                  │  │
│                    │            │            │                  │  │
│                    │  ┌─────────▼─────────┐  │                  │  │
│                    │  │ oak_compendium.db │  │                  │  │
│                    │  │  (project root)   │  │                  │  │
│                    │  └───────────────────┘  │                  │  │
│                    └─────────────────────────┘                  │  │
│                                                                 │  │
│  Profile resolution: --profile flag → OAK_PROFILE env → config  │  │
│                                                                 │  │
└─────────────────────────────────────────────────────────────────┼──┘
                                                                  │
                                              Remote Mode         │
                                              (--profile prod)    │
                                                                  │
                                                     HTTPS        │
                                                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        API Server (api/)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐ │
│  │ main.go     │───▶│ handlers/   │───▶│ db/                     │ │
│  │ (entry)     │    │ (REST API)  │    │ (SQLite)                │ │
│  └─────────────┘    └─────────────┘    └─────────────────────────┘ │
│                                                    │               │
│  Deployed to: Fly.io (oak-compendium-api)          │               │
│  Auth: API key via OAK_API_KEY or ~/.oak/api_key   │               │
│                                                    ▼               │
│                                         /data/oak_compendium.db    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Design Points**:
- All CLI commands use the API client for data operations (unified code path)
- In embedded mode, the API server runs in-process on a random localhost port
- Remote mode uses the exact same client code, just pointed at an external server
- The `internal/db/` package is only used by the embedded API server, not directly by commands

### Data Sources

| Source | ID | Type | Purpose | Import Command |
|--------|-----|------|---------|----------------|
| iNaturalist | 1 | Website | Authoritative taxonomy (subgenera, sections, subsections, complexes) and species list | `oak taxa import`, `oak import-bulk` |
| Oaks of the World | 2 | Website | Rich descriptive data (morphology, distribution, local names) | `oak import-oaksoftheworld` |
| Oak Compendium | 3 | Personal Observation | Field notes, personal observations, curated content | `oak import-bear` |

### Pipeline Steps

**1. Database Initialization (one-time setup)**
```bash
cd cli

# Import taxonomy hierarchy
oak taxa import --clear data/quercus-taxonomy.yaml

# Import species list from iNaturalist
oak import-bulk data/quercus-species.yaml --source-id 1

# Import Oaks of the World descriptive data
oak import-oaksoftheworld <scraped-json> --source-id 2
```

**2. Ongoing Updates (Bear workflow)**
```bash
cd cli

# Import notes from Bear app
oak import-bear --source-id 3

# Changes are immediately available via API (no export needed for web)
```

**3. Updating Production Database**
```bash
# Upload local database changes to Fly.io
fly ssh console -C "rm /data/oak_compendium.db" --app oak-compendium-api
fly ssh sftp put oak_compendium.db /data/oak_compendium.db --app oak-compendium-api
fly apps restart oak-compendium-api

# Web app fetches data from API, so database updates are reflected immediately
```

### Bear App Integration

Bear provides a low-friction way to capture field notes on iOS/macOS. Notes sync via iCloud and are imported into the database.

**Bear SQLite Location:**
```
~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite
```

**Tag Format:**
- Regular species: `#Quercus/{subgenus}/{section}/{species}`
- Hybrids: `#Quercus/{subgenus}/{section}/x/{hybrid}`

**Note Template:**
```markdown
# Quercus {species}

## Common Name(s):
## Taxonomy:
#Quercus/{subgenus}/{section}/{species}
## Identification:
### Leaf:
### Acorn:
### Bark:
### Twigs:
### Buds:
### Form:
## Range & Habitat:
## Field Notes:
## Resources:
## Photos:
```

**Field Mapping:**
| Bear Section | Database Field |
|--------------|----------------|
| Common Name(s) | local_names |
| Leaf | leaves |
| Acorn | fruits |
| Bark | bark (in species_sources) |
| Twigs | twigs (in species_sources) |
| Buds | buds (in species_sources) |
| Form | growth_habit |
| Range & Habitat | range |
| Field Notes | miscellaneous |
| Resources | miscellaneous (appended) |

**Helper Commands:**
```bash
# Generate note templates for species not yet in Bear
oak generate-bear-notes --output ../tmp/bear-notes

# Preview import without making changes
oak import-bear --dry-run
```

### Key Design Decisions

- **Fly.io database is the single source of truth**: The authoritative database is hosted on Fly.io. Local copies are for development only.
- **Source attribution**: Every data point is linked to its source (iNaturalist, Oaks of the World, Personal Observation)
- **Source 3 is preferred**: Personal observations take precedence over other sources for display
- **API is sole source of truth for web**: Web app uses stateless fetch-per-view (no client-side persistence)

## Architecture Decisions

### API Authentication (IMPORTANT - Read This First)

**The API uses `Authorization: Bearer <token>` headers exclusively.**

**Key Files:**
- `api/internal/handlers/auth.go` - Authentication middleware and helpers
- `web/src/lib/apiClient.js` - Web client auth implementation

**Authentication Rules:**

| HTTP Method | Auth Required | Middleware |
|-------------|---------------|------------|
| GET, HEAD, OPTIONS | No | Pass-through (public reads) |
| POST, PUT, DELETE, PATCH | Yes | `RequireAuth()` |
| Special endpoints (e.g., `/auth/verify`) | Yes (all methods) | `ForceAuth()` |

**Server Implementation (`auth.go`):**

```go
// extractBearerToken() extracts from "Authorization: Bearer <token>"
token := extractBearerToken(r)

// isAuthenticated() helper for optional auth checks (e.g., show drafts)
func (s *Server) isAuthenticated(r *http.Request) bool {
    token := extractBearerToken(r)
    return token != "" && ValidateAPIKey(token, s.apiKey)
}
```

**Web Client Implementation (`apiClient.js`):**

```javascript
headers: {
  'Authorization': `Bearer ${apiKey}`,
  'Content-Type': 'application/json'
}
```

**Common Mistakes to Avoid:**
- ❌ Don't use `X-API-Key` header - we use `Authorization: Bearer` only
- ❌ Don't require auth for GET requests - reads are public
- ❌ Don't confuse `RequireAuth` (write-only) with `ForceAuth` (all methods)
- ✅ Use `isAuthenticated()` helper for optional auth (like articles showing drafts)

---

### Stateless Fetch-Per-View Architecture (Decision: 2026-01-02)

**Decision**: Web app fetches data directly from API on each view mount. No client-side persistence.

**Rationale**:
- **Simplicity**: No cache invalidation, no stale data concerns, no format conversions
- **API is single source of truth**: Eliminates sync bugs between client cache and server
- **Each component is self-contained**: Easy to reason about data flow
- **Immediate updates**: Changes are visible on page refresh without complex refresh logic

**Implementation**:
- Each route/component fetches its own data via `apiClient.js`
- Loading states are per-component
- Edit operations re-fetch data with retry logic (3 retries, exponential backoff)

**Trade-offs Accepted**:
- Requires network connection (no offline support - deferred to future initiative)
- More API calls per session (mitigated by gzip compression)
- Replaces previous IndexedDB + static JSON architecture

**Issue Reference**: oaks-* (refactor-web-data-layer)

## Data Structure

### Database Schema

The SQLite database schema is defined in `api/internal/db/schema/schema.sql`. This is the single source of truth. To view the current schema:

```bash
sqlite3 oak_compendium.db ".schema"
```

### API Response Format

The web app fetches data directly from API endpoints. Example from `GET /api/v1/species/{name}/full`:

```json
{
  "scientific_name": "alba",
  "author": "L. 1753",
  "is_hybrid": false,
  "conservation_status": "LC",
  "subgenus": "Quercus",
  "section": "Quercus",
  "subsection": null,
  "complex": null,
  "parent1": null,
  "parent2": null,
  "hybrids": ["bebbiana"],
  "closely_related_to": ["stellata"],
  "subspecies_varieties": ["alba var. latiloba"],
  "synonyms": ["alba var. repanda"],
  "sources": [
    {
      "source_id": 1,
      "source_name": "Oaks of the World",
      "source_url": "https://oaksoftheworld.fr",
      "is_preferred": true,
      "local_names": ["white oak", "eastern white oak"],
      "range": "Eastern North America; 0 to 1600 m",
      "growth_habit": "reaches 25 m high...",
      "leaves": "8-20 cm long...",
      "flowers": "...",
      "fruits": "...",
      "bark": "...",
      "twigs": "...",
      "buds": "...",
      "hardiness_habitat": "...",
      "miscellaneous": "...",
      "url": "https://oaksoftheworld.fr/species/alba"
    }
  ]
}
```

**Key Conventions**:
- Field name is `scientific_name` (API format), without "Quercus" prefix
- Taxonomy fields are flat (not nested under `taxonomy` object)
- Hybrid indicator: `is_hybrid` boolean + `×` in name
- All fields are optional except `scientific_name` and `is_hybrid`
- `sources` array contains data from different sources
- `is_preferred` marks the primary source for display when sources conflict

## Scraper Architecture

### Key Modules

**scraper.py** - Main orchestration:
- Fetches species list from `liste.htm`
- Iterates through species pages
- Handles resume/restart logic
- Saves progress every 10 species
- Outputs final JSON

**name_parser.py** - Species list parsing:
- Parses `liste.htm` using complex rules (see `parsing_rules.txt`)
- Identifies hybrids via `×` character or `(x)` notation
- Builds synonym map
- Returns list of species URLs to scrape

**parser.py** - Individual page parsing:
- Extracts all morphological data
- Parses taxonomy (subgenus/section/series from Oaks of the World; CLI uses "complex" from iNaturalist)
- Identifies hybrid parents from formulas like "alba x macrocarpa"
- Function: `build_hybrid_relationships()` creates bidirectional links

**utils.py** - Infrastructure:
- `fetch_page()`: HTTP with caching and rate limiting (0.5s delay)
- Progress tracking: `load_progress()`, `save_progress()`
- Cache management: `tmp/scraper/html_cache/` directory
- Inconsistency logging: `tmp/scraper/data_inconsistencies.log`

### Scraper State Management

**Progress File**: `tmp/scraper/scraper_progress.json`
```json
{
  "species_links": [...],      // All URLs to scrape
  "synonym_map": {...},        // Name → canonical name mapping
  "completed": [...],          // Successfully scraped URLs
  "failed": [...],             // Failed URLs
  "species_data": [...]        // Accumulated species objects
}
```

Progress auto-saves every 10 species. Delete progress file or use `--restart` to start fresh.

## CLI Tool Design

The Go CLI (`oak`) manages taxonomic data with strict validation and source attribution. It uses an HTTP API client for all operations, communicating with either an embedded local server or a remote API.

### Core Concepts

**Unified API Architecture**: All commands use the same HTTP client code path, regardless of whether operating in embedded mode (local database) or remote mode (external API server).

**Source-Attributed Data**: Every data point is linked to a specific source. Conflicts only occur when updating data from the *same* source.

**Editor-Based Workflow**: Uses `$EDITOR` for structured YAML editing with strict schema validation.

### Key Commands

```bash
oak new <name>                   # Create new entry (opens $EDITOR)
oak edit <name>                  # Edit existing entry
oak delete <name>                # Delete entry (with confirmation)
oak find <query> [-i]            # Search (use -i for pipeline-friendly IDs)
oak source new                   # Create source entry interactively
oak source list                  # List all sources
oak source edit <id>             # Edit source in $EDITOR
oak add-value <field> <value>    # Add enumeration value to schema
oak import-bulk <file> --source-id <ID>  # Bulk import with conflict resolution
```

**Technology Stack**:
- Language: Go
- CLI Framework: `cobra`
- HTTP Client: Built-in net/http with retry logic
- Validation: JSON Schema via `jsonschema`
- Serialization: YAML via `yaml.v3`

## Web Application Details

See `web/CLAUDE.md` for comprehensive documentation. Key points:

- **Framework**: SvelteKit with Svelte 5 (runes)
- **Data**: Stateless fetch-per-view from API (no client-side persistence)
- **Routing**: SvelteKit file-based routing
- **Styling**: Tailwind 4 + CSS custom properties
- **Editing**: Full CRUD via authenticated API calls

## Development Environment Setup

### Python (Scraper)

```bash
# Create/activate virtual environment
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# venv\Scripts\activate   # Windows

# Install dependencies
cd scrapers/oaksoftheworld
pip install -r requirements.txt
```

### JavaScript (Web App)

```bash
cd web
npm install
```

### Go (CLI)

```bash
cd cli
go build -o oak .
```

## Important Conventions

### File Naming
- Python: `snake_case.py`
- JavaScript: `PascalCase.svelte`, `camelCase.js`
- Go: `snake_case.go`

### Code Style
- **Python**: PEP 8, docstrings on functions, meaningful variable names
- **JavaScript**: 2-space indent, see `web/CLAUDE.md` for Svelte conventions
- **Go**: `gofmt`, API client pattern for data operations

### Git Workflow

**IMPORTANT: Never checkout `main` directly.** The beads daemon uses a sparse worktree on `main` for auto-sync. Attempting to checkout `main` will fail.

**Push approval rules:**
| Change Type | Approval Required | Notes |
|-------------|-------------------|-------|
| Beads (`.beads/`) | No | Daemon auto-syncs to main |
| Specs (`/openspec/`) | No | But must be manually pushed to main |
| Everything else | **Yes** | Always ask user before pushing to main |

**Workflow for small work (bugs, specs, small features):**
```bash
# Start from origin/main
git fetch origin
git checkout -b fix/descriptive-name origin/main

# Do work, commit
git add <files>
git commit -m "Description"

# For specs: push to main immediately
git push origin fix/descriptive-name:main
git checkout --detach origin/main
git branch -d fix/descriptive-name

# For code: ASK USER FIRST, then push if approved
```

**Workflow for large features:**
```bash
# Create a worktree for the feature
git worktree add ../oaks-feature-name -b feature-name origin/main

# Work in that directory until complete
# When ready to merge: ASK USER FOR APPROVAL
```

**Specs rule:** When specs in `/openspec/` are modified (even while on a feature branch), ensure they get pushed to main. Create a separate branch from `origin/main` if needed.

**Beads:** The daemon (auto-commit, auto-push, auto-pull) handles all beads sync automatically.

**Commit messages:** Present tense, imperative mood.

### Releasing

When the user asks to release a component (web, api, ios):

1. **Read `/RELEASING.md`** for the full process
2. **Create a tracking beads issue** using the template in `.beads/templates/`
3. **Follow the checkpoints** and update the issue as you progress
4. **This is critical for recovery** - if the session dies, the next agent can resume from the last checkpoint

Quick reference:
```bash
# Create release tracking issue
bd create --title "Release web $(date +%Y.%m.%d.%H%M)" --type task --priority 0

# Version format: YYYY.MM.DD.HHMM (e.g., 2025.01.03.1430)
# Version file: /version.json
```

### Beads Naming
Use component prefixes when creating beads:
- `cli-` for CLI tool issues
- `web-` for web application issues
- `ios-` for iOS app issues

Ask before introducing new prefixes.

### Multi-Agent Workflows
For parallel agent work, use separate worktrees:
- Main working dir: bugs, specs, small work
- Feature worktrees: large features (e.g., `../oaks-feature-name`)

All worktrees share beads state via the daemon's `sync.branch=main` configuration.

### Database Management
- **Authoritative source**: The production database on Fly.io (`/data/oak_compendium.db`) is the single source of truth
- **Local copy**: `oak_compendium.db` (project root) is committed to git for convenience but is NOT authoritative
- **Syncing**: Use `make download-db` to pull the latest from Fly.io before local development
- **Uploading changes**: After making local changes, use the Fly.io upload process (see `api/README.md`)

### CLI Profile Configuration

To connect the CLI to a remote API server, create `~/.oak/config.yaml`:

```yaml
profiles:
  prod:
    url: https://oak-compendium-api.fly.dev
    key: your-api-key-here
  local-server:
    url: http://localhost:8080
    key: dev-key

# Uncomment to default to remote instead of local
# default_profile: prod
```

See `cli/README.md` for full profile configuration details.

### Fly.io Deployment
- **Region**: Always use `iad` (Ashburn, Virginia) for Fly.io resources
- **App name**: `oak-compendium-api`
- **Dockerfile**: `api/Dockerfile`
- **Configuration**: `fly.toml` in project root
- When creating volumes or machines, always specify `--region iad`
- See `api/README.md` for deployment instructions

## Testing

### Scraper Testing
```bash
cd scrapers/oaksoftheworld

# Test name parser
python3 test_name_parser.py

# Test with limited species
python3 scraper.py --test  # First 50 species
```

### Web App Testing
```bash
cd web
npm run test           # Run tests once
npm run test:watch     # Watch mode for development
npm run test:coverage  # Run with coverage report
npm run dev            # Manual testing in browser
```

### CLI Testing
```bash
cd cli
go test ./...
```

### API Testing
```bash
cd api
go test ./...
make test-coverage  # With HTML coverage report
```

## Data Validation

### Scraper Output Validation
After running scraper, verify:
1. Scraper output file exists (typically in `tmp/scraper/`)
2. JSON is valid: `python3 -m json.tool <output-file> > /dev/null`
3. Check `tmp/scraper/data_inconsistencies.log` for taxonomic issues
4. Import to database: `cd cli && oak import-oaksoftheworld <output-file>`

### Web App Data Loading
The web app fetches data directly from the API on each view mount. If API schema changes:
- Update display logic in components (e.g., `SpeciesDetail.svelte`)
- No code changes required for new optional fields (they're simply ignored until displayed)

## Performance Considerations

### Scraper
- Rate limiting: 0.5 second delay between requests (hardcoded in `utils.py`)
- Caching: HTML pages cached in `tmp/scraper/html_cache/` to avoid re-fetching
- Use `--no-cache` flag only for testing/debugging

### Web App
- Fetch-per-view architecture (species list ~150KB gzipped)
- API search endpoint for filtering
- No client-side caching (API is source of truth)
- Gzip compression on all API responses

## Troubleshooting

### Scraper Issues
- **SSL errors**: Use `--no-ssl-verify` flag (not recommended)
- **Stuck progress**: Check `tmp/scraper/scraper_progress.json`, use `--restart` to clear
- **Missing data**: Check `tmp/scraper/data_inconsistencies.log` for parsing issues
- **Cache problems**: Delete `tmp/scraper/html_cache/` directory or use `--no-cache`

### Web App Issues
- **Data not loading**: Check browser console, verify API is reachable
- **API errors**: Check network tab for failed requests, verify API server is running
- **Build fails**: Delete `node_modules/` and `package-lock.json`, run `npm install`

### CLI Issues
- **Build errors**: Run `go clean && go build -o oak .`
- **Database locked** (embedded mode): Only one process can access the local SQLite database at a time
- **Connection refused** (remote mode): Check that the API server is running and the profile URL is correct

## Future Enhancements

See `README.md` for project roadmap. Key planned features:
- Geographic filtering and map view
- Taxonomy tree visualization
- Image gallery integration
- Advanced search filters (by section, range, etc.)
- CSV/PDF export functionality
- CLI bulk import completion
