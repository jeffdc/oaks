# Project Context

## Purpose

The Quercus Database is a comprehensive database and query tool for oak (Quercus) species and their hybrids. Goals:

- Aggregate oak species data from multiple authoritative sources
- Provide offline-capable web and mobile apps for field identification
- Enable structured note-taking and personal observations via API sync (replacing Bear app workflow)
- Maintain source attribution for all data points

## Tech Stack

### Web Application (`web/`)
- **Framework**: Svelte 5 with runes
- **Build**: Vite
- **Styling**: Tailwind CSS 4 + CSS custom properties
- **Storage**: IndexedDB via Dexie.js (offline-first PWA)
- **PWA**: vite-plugin-pwa with service worker

### CLI Tool (`cli/`)
- **Language**: Go
- **Database**: SQLite via go-sqlite3
- **CLI Framework**: Cobra
- **Validation**: JSON Schema via jsonschema
- **Serialization**: YAML via yaml.v3

### API Server (planned, see `add-crud-api-server` change)
- **Framework**: Chi router (net/http compatible)
- **Auth**: API key for write operations only
- **Deployment**: Fly.io with persistent volume
- **Domain**: api.oakcompendium.com (planned)

### Python Scraper (`scrapers/oaksoftheworld/`)
- **Libraries**: BeautifulSoup4, requests, lxml
- **Caching**: File-based HTML cache in `tmp/scraper/`

### iOS App (`ios/`)
- **Framework**: SwiftUI
- **Target**: iOS (in development)

## Project Conventions

### Code Style

| Component | Convention |
|-----------|------------|
| Python | PEP 8, docstrings on functions, `snake_case.py` files |
| JavaScript/Svelte | 2-space indent, `PascalCase.svelte`, `camelCase.js` |
| Go | `gofmt`, `snake_case.go`, Repository Pattern for DB access |

### Architecture Patterns

- **CLI as single source of truth**: All data flows through `cli/oak_compendium.db`
- **Source attribution**: Every data point linked to its source (iNaturalist, Oaks of the World, Personal Observation)
- **Denormalized JSON export**: CLI exports to `web/static/quercus_data.json` for web consumption
- **IndexedDB for offline**: Web app loads JSON once, populates IndexedDB for querying

### Testing Strategy

- **Web**: Vitest (`npm run test`, `npm run test:watch`, `npm run test:coverage`)
- **CLI**: Go standard testing (`go test ./...`)
- **Scraper**: Manual testing with `--test` flag (first 50 species)

### Git Workflow

- **Issue tracking**: Beads (`bd` commands) instead of markdown TODOs
- **Commit messages**: Present tense, imperative mood
- **Beads sync**: Run `bd sync` at session start and end
- **Bead prefixes**: Use `cli-`, `web-`, `ios-` when creating issues

## Domain Context

### Taxonomy Hierarchy
Oak taxonomy follows: Genus → Subgenus → Section → Subsection → Complex → Species

### Hybrid Naming
- Hybrids marked with `×` in name (e.g., "×bebbiana")
- `is_hybrid` boolean flag
- `parent1` and `parent2` track parentage

### Data Sources
| ID | Source | Purpose |
|----|--------|---------|
| 1 | iNaturalist | Authoritative taxonomy |
| 2 | Oaks of the World | Rich descriptive data |
| 3 | Oak Compendium | Personal observations via iOS app (preferred for display) |

### Species Names
Stored WITHOUT "Quercus" prefix (e.g., "alba" not "Quercus alba")

## Important Constraints

- **Database location**: `cli/oak_compendium.db` MUST be committed to git (authoritative source)
- **Run CLI from `cli/` directory**: Tool defaults to `oak_compendium.db` in cwd
- **No destructive commands**: Never `rm` or `mv` without user confirmation
- **Stay in project directories**: Don't operate outside `oaks/` without explicit approval

## External Dependencies

### Data Sources
- **oaksoftheworld.fr**: Primary scraping target for species descriptions
- **iNaturalist**: Taxonomy hierarchy and species list
- **Oak Compendium API**: Personal notes via RESTful API (replacing Bear App workflow, see `replace-bear-with-ios-sync` change)

### Deployment
- **GitHub Pages**: Web app deployed via GitHub Actions on push to main
- **Fly.io**: API server deployed via GitHub Actions (planned, see `add-crud-api-server`)
- **GitHub Actions**: `.github/workflows/deploy.yml` (web), `.github/workflows/deploy-api.yml` (API, planned)
