# V1 Reference Documentation

This file contains detailed documentation for the V1 components (Go API, Svelte web, CLI, Python scraper). These are frozen and read-only — use as reference when building V2.

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

## V1 Development Workflows

### Full Stack Development

```bash
make dev        # Start API (:8080) + web dev server (:5173)
make dev-api    # API server only
make dev-web    # Web dev server (connects to local API)
make build      # Build all components
make test       # Run all tests
```

### Python Scraper

```bash
cd scrapers/oaksoftheworld
source ../../venv/bin/activate
pip install -r requirements.txt

python3 scraper.py              # Auto-resumes from last position
python3 scraper.py --restart    # Force restart
python3 scraper.py --test       # First 50 species
python3 scraper.py --limit=10   # Process specific number

# Output: ../../tmp/scraper/quercus_data.json
# Import: cd ../../cli && oak import-oaksoftheworld ../tmp/scraper/quercus_data.json
```

### Web Application

```bash
cd web
npm install
npm run dev          # Uses production API
npm run dev:local    # Uses local API (localhost:8080)
npm run build        # Production build (dist/)
```

The web app fetches data directly from the API (stateless fetch-per-view). GitHub Actions deploys on push to main.

### CLI Tool

```bash
cd cli
make build       # or: go build -o oak .
./oak <subcommand>

# Key commands
oak new <name>                   # Create new entry (opens $EDITOR)
oak edit <name>                  # Edit existing entry
oak delete <name>                # Delete entry
oak find <query> [-i]            # Search
oak source new                   # Create source entry
oak source list                  # List all sources
oak import-bulk <file> --source-id <ID>  # Bulk import
```

**Local vs Remote Mode**:
- Default: operates on local SQLite database
- `--profile <name>`: connect to remote API server
- `--local`: force local mode
- `--remote`: force remote mode

### API Server

```bash
cd api
make build && make run
# Or: OAK_DB_PATH=../oak_compendium.db OAK_PORT=8080 ./oak-api
```

**Environment Variables**: `OAK_DB_PATH`, `OAK_PORT`, `OAK_API_KEY`

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                                │
├─────────────────────────────────────────────────────────────────────┤
│  iNaturalist            Oaks of the World         Bear App          │
│  (Source 1)             (Source 2)                (Source 3)        │
│  taxonomy + species     descriptive data          personal notes    │
│         │                      │                       │            │
│         ▼                      ▼                       ▼            │
│  cli/data/*.yaml        scrapers/oaksoftheworld/  Bear SQLite      │
└─────────┼──────────────────────┼───────────────────────┼────────────┘
          │                      │                       │
          ▼                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│              CLI TOOL (oak) → oak_compendium.db (SQLite)            │
└─────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│  API Server (Fly.io) → Web App (Svelte, fetch-per-view)            │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Sources

| Source | ID | Type | Purpose | Import Command |
|--------|-----|------|---------|----------------|
| iNaturalist | 1 | Website | Authoritative taxonomy and species list | `oak taxa import`, `oak import-bulk` |
| Oaks of the World | 2 | Website | Rich descriptive data (morphology, distribution, local names) | `oak import-oaksoftheworld` |
| Oak Compendium | 3 | Personal Observation | Field notes, personal observations, curated content | `oak import-bear` |

### Pipeline Steps

**Database Initialization (one-time)**:
```bash
cd cli
oak taxa import --clear data/quercus-taxonomy.yaml
oak import-bulk data/quercus-species.yaml --source-id 1
oak import-oaksoftheworld <scraped-json> --source-id 2
```

**Ongoing Updates (Bear workflow)**:
```bash
cd cli
oak import-bear --source-id 3
```

**Updating Production Database**:
```bash
fly ssh console -C "rm /data/oak_compendium.db" --app oak-compendium-api
fly ssh sftp put oak_compendium.db /data/oak_compendium.db --app oak-compendium-api
fly apps restart oak-compendium-api
```

## Bear App Integration

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
oak generate-bear-notes --output ../tmp/bear-notes  # Generate templates
oak import-bear --dry-run                            # Preview import
```

## API Authentication

**The API uses `Authorization: Bearer <token>` headers exclusively.**

| HTTP Method | Auth Required | Middleware |
|-------------|---------------|------------|
| GET, HEAD, OPTIONS | No | Pass-through (public reads) |
| POST, PUT, DELETE, PATCH | Yes | `RequireAuth()` |
| Special endpoints (e.g., `/auth/verify`) | Yes (all methods) | `ForceAuth()` |

**Key Files:**
- `api/internal/handlers/auth.go` - Authentication middleware
- `web/src/lib/apiClient.js` - Web client auth

**Common Mistakes:**
- Don't use `X-API-Key` header — use `Authorization: Bearer` only
- Don't require auth for GET requests — reads are public
- Use `isAuthenticated()` helper for optional auth (like articles showing drafts)

## API Response Format

Example from `GET /api/v1/species/{name}/full`:

```json
{
  "scientific_name": "alba",
  "author": "L. 1753",
  "is_hybrid": false,
  "conservation_status": "LC",
  "subgenus": "Quercus",
  "section": "Quercus",
  "sources": [
    {
      "source_id": 1,
      "source_name": "Oaks of the World",
      "is_preferred": true,
      "local_names": ["white oak", "eastern white oak"],
      "range": "Eastern North America; 0 to 1600 m",
      "growth_habit": "reaches 25 m high...",
      "leaves": "8-20 cm long...",
      "fruits": "...",
      "bark": "...",
      "url": "https://oaksoftheworld.fr/species/alba"
    }
  ]
}
```

**Key Conventions**:
- `scientific_name` without "Quercus" prefix
- Taxonomy fields are flat (not nested)
- Hybrid indicator: `is_hybrid` boolean + `×` in name
- `is_preferred` marks the primary source for display

## Scraper Architecture

**scraper.py** - Main orchestration: fetches species list, iterates pages, saves progress every 10 species.

**name_parser.py** - Parses `liste.htm`, identifies hybrids via `×` character, builds synonym map.

**parser.py** - Extracts morphological data, parses taxonomy, identifies hybrid parents.

**utils.py** - HTTP with caching (0.5s rate limit), progress tracking, cache at `tmp/scraper/html_cache/`.

**Progress File**: `tmp/scraper/scraper_progress.json` — auto-saves, use `--restart` to clear.

## CLI Profile Configuration

```yaml
# ~/.oak/config.yaml
profiles:
  prod:
    url: https://oak-compendium-api.fly.dev
    key: your-api-key-here
  local-server:
    url: http://localhost:8080
    key: dev-key
```

## V1 Testing

```bash
cd scrapers/oaksoftheworld && python3 test_name_parser.py  # Scraper
cd web && npm run test                                      # Web
cd cli && go test ./...                                     # CLI
cd api && go test ./...                                     # API
```

## Troubleshooting

### Scraper
- **SSL errors**: `--no-ssl-verify` (not recommended)
- **Stuck progress**: Check `tmp/scraper/scraper_progress.json`, use `--restart`
- **Cache problems**: Delete `tmp/scraper/html_cache/`

### Web App
- **Data not loading**: Check browser console, verify API is reachable
- **Build fails**: Delete `node_modules/` and `package-lock.json`, run `npm install`

### CLI
- **Database locked**: Only one process can access local SQLite at a time
- **Connection refused**: Check API server is running and profile URL is correct
