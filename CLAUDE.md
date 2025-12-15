# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads) for issue tracking. Use `bd` commands instead of markdown TODOs. See AGENTS.md for workflow details.

## Project Overview

The Quercus Database is a comprehensive database and query tool for oak (Quercus) species and their hybrids. The project consists of three main components:

1. **Python Scraper** - Extracts oak species data from oaksoftheworld.fr
2. **Web Application** - Modern Svelte 5 PWA for browsing species data
3. **CLI Tool** - Go-based command-line tool for managing taxonomic data (in development)

## Repository Structure

```
oaks/
├── scrapers/oaksoftheworld/  # Python web scraper
│   ├── scraper.py            # Main scraper orchestration
│   ├── name_parser.py        # Parses species list (liste.htm)
│   ├── parser.py             # Parses individual species pages
│   ├── utils.py              # Caching, progress tracking, HTTP utilities
│   └── requirements.txt      # beautifulsoup4, requests, lxml
├── web/                      # Svelte 5 PWA (see web/CLAUDE.md for details)
│   ├── src/                  # Svelte components and stores
│   └── package.json          # Vite, Svelte 5, Tailwind 4
├── cli/                      # Go CLI tool (in development)
│   ├── cmd/                  # Cobra command implementations
│   ├── internal/             # Internal packages (db, models, schema, editor)
│   ├── go.mod                # cobra, go-sqlite3, yaml.v3, jsonschema
│   └── docs/oak_cli.md       # CLI specification (historical)
├── tmp/                      # Temporary/working files (gitignored)
│   ├── scraper/              # Scraper cache and progress files
│   └── data/                 # Working data files (e.g., iNaturalist imports)
└── quercus_data.json         # JSON export for web consumption
```

## Common Development Tasks

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

# Output location: ../../quercus_data.json
```

### Web Application Workflow

```bash
cd web

# Install dependencies
npm install

# Development server (http://localhost:5173)
npm run dev

# Production build
npm run build      # Output: dist/
npm run preview    # Preview production build
```

**Important**: The web app's `vite.config.js` includes a custom plugin that copies `../quercus_data.json` to `public/` during build. The app loads this JSON and populates IndexedDB for offline queries. See `web/CLAUDE.md` for detailed architecture.

### CLI Tool Workflow

```bash
cd cli

# Build
go build -o oak .

# Run directly
./oak <subcommand>

# Or run with go
go run . <subcommand>

# Install to $GOPATH/bin
go install .
```

**Note**: The CLI is in early development. See `cli/docs/oak_cli.md` for historical specification (may be outdated).

## Data Flow Architecture

The complete data pipeline from sources to browser:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  iNaturalist                      Oaks of the World                 │
│  (taxonomy + species list)        (descriptive data)                │
│         │                                │                          │
│         ▼                                ▼                          │
│  cli/data/quercus-taxonomy.yaml   scrapers/oaksoftheworld/          │
│  cli/data/quercus-species.yaml           │                          │
│         │                                │                          │
└─────────┼────────────────────────────────┼──────────────────────────┘
          │                                │
          ▼                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         CLI TOOL (oak)                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  oak taxa import ...          oak import-oaksoftheworld ...         │
│  oak import-bulk ...                                                │
│         │                                │                          │
│         └────────────┬───────────────────┘                          │
│                      ▼                                              │
│              oak_compendium.db (SQLite)                             │
│              ├── taxa (taxonomy hierarchy)                          │
│              ├── oak_entries (species)                              │
│              ├── sources (data sources)                             │
│              └── species_sources (source-attributed data)           │
│                      │                                              │
│                      ▼                                              │
│              oak export quercus_data.json                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      quercus_data.json                              │
│                 (denormalized JSON for web)                         │
└─────────────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      WEB APP (Svelte PWA)                           │
├─────────────────────────────────────────────────────────────────────┤
│  1. Fetch quercus_data.json                                         │
│  2. Populate IndexedDB (via Dexie.js)                               │
│  3. Query from IndexedDB for UI                                     │
│  4. Service worker caches for offline                               │
└─────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
                        ┌─────────────────────────────────────────────┐
                        │         USER'S BROWSER                      │
                        │  • Offline-capable queries via IndexedDB    │
                        │  • Service worker serves cached assets      │
                        └─────────────────────────────────────────────┘
```

### Pipeline Steps

**1. Data Sources**
- **iNaturalist**: Provides authoritative taxonomy (subgenera, sections, subsections, complexes) and species list. Stored as seed files in `cli/data/`.
- **Oaks of the World**: Provides rich descriptive data (morphology, distribution, local names). Scraped via Python scripts.

**2. CLI Database (oak_compendium.db)**
```bash
# Initialize from seed files
oak taxa import --clear cli/data/quercus-taxonomy.yaml
oak import-bulk cli/data/quercus-species.yaml --source-id 1

# Import Oaks of the World data
oak import-oaksoftheworld <json-file> --source-id 2
```

**3. JSON Export**
```bash
# Generate web-ready JSON
oak export ../quercus_data.json
```

**4. Web App Loading**
- Vite build copies `quercus_data.json` to `public/`
- App fetches JSON on startup
- Data populates IndexedDB for structured queries
- Service worker caches everything for offline use

### Key Design Decisions

- **CLI is the single source of truth**: All data flows through the CLI database
- **Source attribution**: Every data point is linked to its source (iNaturalist, Oaks of the World, etc.)
- **Denormalized JSON export**: Optimized for web consumption, not storage efficiency
- **IndexedDB for offline**: Browser-native storage with query capabilities

## Architecture Decisions

### IndexedDB for Offline PWA (Decision: 2025-12-14, Revised)

**Decision**: Use IndexedDB (via Dexie.js wrapper) for structured, offline-capable data storage in the web application.

**Rationale**:
- **Native Browser API**: No WASM dependencies, no external runtime issues
- **Offline-First Design**: IndexedDB is specifically designed for offline PWA use cases
- **Mature & Stable**: Battle-tested since 2015, excellent browser support (95%+ coverage)
- **Structured Storage**: Objects with indexes, queryable without full SQL complexity
- **Proven Reliability**: Production-ready, no experimental technology risks
- **Small Bundle**: Dexie.js is ~20KB (vs 200KB+ for SQLite WASM)

**Implementation**:
- **Library**: [Dexie.js](https://dexie.org/) - clean wrapper around IndexedDB API
- **Data Flow**: CLI exports JSON → Web app loads → Populate IndexedDB → Query from IndexedDB
- **Persistence**: IndexedDB native persistence (no VFS layers needed)
- **Caching**: Service worker caches JSON file for initial/update loads
- **Queries**: Use Dexie's collection API for filtering, searching, sorting

**Migration Path**:
1. Current: JSON-based web app (keep for initial load)
2. Add: IndexedDB population on first load and updates
3. Migrate: All queries/filters to use IndexedDB
4. Optimize: Only fetch JSON for updates, serve from IndexedDB for queries

**Trade-offs Accepted**:
- Initial load requires JSON parsing + IndexedDB population (one-time cost)
- Query syntax is JavaScript-based, not SQL (acceptable for our use case)
- No server-side SQLite file reuse (but JSON export is simple)

---

### ⚠️ Failed Approach: SQLite WASM (2025-12-14)

**What Happened**: Claude Code initially recommended wa-sqlite (SQLite via WASM) based on web research showing good browser support, performance benchmarks, and OPFS integration. However, practical implementation revealed critical issues:

**Problems Encountered**:
- WASM factory initialization hangs indefinitely in Vite (despite successful file loading)
- Integration between wa-sqlite, Vite, and modern build tools is unreliable
- Technology is too immature for production use despite marketing claims
- Multiple hours spent debugging with no successful POC

**Lesson for Future Claude Code Instances**:
- **Don't trust web research alone** - articles and benchmarks don't equal production-ready
- **Prefer boring, proven technology** over bleeding-edge solutions (IndexedDB > WASM SQLite)
- **Be skeptical of new WASM libraries** - browser APIs are more reliable than compiled alternatives
- **Validate before recommending** - if you can't test it, acknowledge uncertainty
- **Consider implementation complexity** - native APIs beat complex external dependencies

This failed POC wasted time and would have derailed the project if committed. Always prefer mature, boring solutions over exciting new technology when reliability matters.

**Issue References**: oaks-5oo (research), oaks-j9s (failed POC)

---

### JSON Export Format for Web App (Decision: 2025-12-14)

**Decision**: Use a denormalized, single-file JSON format for CLI-to-web-app data export.

**Format Characteristics**:
- **Single file**: `quercus_data.json` contains all data
- **Full export**: Always export complete dataset (no incremental updates)
- **Denormalized structure**: Embed taxonomy and source data within each species object
- **Simple updates**: Re-download entire file when updates are available

**Rationale**:
- **Dataset size**: ~670 species, minimal growth expected (only new sources added over time)
- **Transport only**: JSON is just a transport format; data is converted to IndexedDB for querying
- **Simplicity**: Denormalized format is easiest to iterate and populate IndexedDB
- **File size acceptable**: At this scale (~1-2MB), denormalization overhead is negligible
- **Future flexibility**: Can split into multiple files later if needed

**JSON Structure**:
```json
{
  "species": [
    {
      "name": "alba",
      "author": "L. 1753",
      "is_hybrid": false,
      "conservation_status": "LC",
      "taxonomy": {
        "genus": "Quercus",
        "subgenus": "Quercus",
        "section": "Quercus",
        "subsection": null,
        "complex": null
      },
      "parent1": null,
      "parent2": null,
      "sources": [
        {
          "source_id": 1,
          "source_name": "Oaks of the World",
          "source_url": "https://oaksoftheworld.fr/...",
          "is_preferred": true,
          "leaves": "...",
          "flowers": "...",
          "fruits": "...",
          "synonyms": [...],
          "local_names": [...]
        }
      ]
    }
  ]
}
```

**Trade-offs Accepted**:
- Duplicates taxonomy metadata across species (acceptable at this scale)
- Must re-download entire file for updates (simple, fast enough for our use case)
- Larger file size than normalized format (negligible impact)

**Benefits**:
- Easy to iterate in JavaScript and populate IndexedDB
- Matches typical display needs (show species with all its data)
- No complex joins or assembly required on client side
- Service worker can cache efficiently

**Issue Reference**: oaks-e9p

## Data Structure

### CLI Database Schema

The SQLite database (`oak_compendium.db`) has four tables:

**oak_entries** (core species data):
- `scientific_name` (PRIMARY KEY), `author`, `is_hybrid`, `conservation_status`
- Taxonomy: `subgenus`, `section`, `subsection`, `complex`
- Relationships: `parent1`, `parent2`, `hybrids`, `closely_related_to`
- `subspecies_varieties`, `synonyms` (both stored as JSON arrays)

**species_sources** (source-attributed descriptive data):
- `scientific_name`, `source_id`, `is_preferred`
- `local_names`, `range`, `growth_habit`
- `leaves`, `flowers`, `fruits`, `bark_twigs_buds`
- `hardiness_habitat`, `miscellaneous`, `url`

**taxa** (taxonomy hierarchy):
- `name`, `level` (subgenus/section/subsection/complex), `parent`, `author`, `notes`, `links`

**sources** (data source registry):
- `id`, `source_type`, `name`, `description`, `author`, `year`, `url`, `isbn`, `doi`, `notes`

### JSON Export Schema (quercus_data.json)

The `oak export` command produces this denormalized format:

```json
{
  "species": [
    {
      "name": "alba",
      "author": "L. 1753",
      "is_hybrid": false,
      "conservation_status": "LC",
      "taxonomy": {
        "genus": "Quercus",
        "subgenus": "Quercus",
        "section": "Quercus",
        "subsection": null,
        "complex": null
      },
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
          "bark_twigs_buds": "...",
          "hardiness_habitat": "...",
          "miscellaneous": "...",
          "url": "https://oaksoftheworld.fr/species/alba"
        }
      ]
    }
  ]
}
```

**Key Conventions**:
- Species names stored WITHOUT "Quercus" prefix (e.g., "alba" not "Quercus alba")
- Hybrid indicator: `is_hybrid` boolean + `×` in name
- All fields are optional except `name` and `is_hybrid`
- `sources` array contains data from different sources (e.g., iNaturalist, Oaks of the World)
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

## CLI Tool Design (In Development)

The Go CLI (`oak`) manages taxonomic data with strict validation and source attribution.

### Core Concepts

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
- Database: SQLite via `go-sqlite3`
- CLI Framework: `cobra`
- Validation: JSON Schema via `jsonschema`
- Serialization: YAML via `yaml.v3`

## Web Application Details

See `web/CLAUDE.md` for comprehensive documentation. Key points:

- **Framework**: Svelte 5 with runes
- **State**: Svelte stores in `dataStore.js`
- **Routing**: Browser History API (no router library)
- **Styling**: Tailwind 4 + CSS custom properties
- **PWA**: Full offline support via `vite-plugin-pwa`

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
- **Go**: `gofmt`, Repository Pattern for DB access

### Git Workflow
- This project uses Beads for issue tracking (see `.beads/` and session startup hook)
- Before completing work: `bd sync --from-main` to pull latest beads
- Commit messages: Present tense, imperative mood (see `CONTRIBUTING.md`)

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
npm run dev  # Manual testing in browser
```

### CLI Testing
```bash
cd cli
go test ./...
```

## Data Validation

### Scraper Output Validation
After running scraper, verify:
1. `quercus_data.json` exists in root directory
2. JSON is valid: `python3 -m json.tool quercus_data.json > /dev/null`
3. Check `tmp/scraper/data_inconsistencies.log` for taxonomic issues
4. Test in web app: `cd web && npm run dev`

### Web App Data Loading
The web app fetches `/quercus_data.json` at startup. If schema changes:
- Update display logic in `SpeciesDetail.svelte`
- Update search logic in `dataStore.js` if needed
- No code changes required for new optional fields

## Performance Considerations

### Scraper
- Rate limiting: 0.5 second delay between requests (hardcoded in `utils.py`)
- Caching: HTML pages cached in `tmp/scraper/html_cache/` to avoid re-fetching
- Use `--no-cache` flag only for testing/debugging

### Web App
- Single JSON fetch on load (~1.2MB for ~500 species)
- Client-side filtering (fast enough for current dataset)
- Service worker caches everything for offline use
- No lazy loading needed currently

## Troubleshooting

### Scraper Issues
- **SSL errors**: Use `--no-ssl-verify` flag (not recommended)
- **Stuck progress**: Check `tmp/scraper/scraper_progress.json`, use `--restart` to clear
- **Missing data**: Check `tmp/scraper/data_inconsistencies.log` for parsing issues
- **Cache problems**: Delete `tmp/scraper/html_cache/` directory or use `--no-cache`

### Web App Issues
- **Data not loading**: Check browser console, verify `quercus_data.json` exists
- **PWA not updating**: Clear service worker cache in browser DevTools
- **Build fails**: Delete `node_modules/` and `package-lock.json`, run `npm install`

### CLI Issues
- **Build errors**: Run `go clean && go build -o oak .`
- **Database locked**: Only one process can access SQLite at a time

## Future Enhancements

See `README.md` for project roadmap. Key planned features:
- Geographic filtering and map view
- Taxonomy tree visualization
- Image gallery integration
- Advanced search filters (by section, range, etc.)
- CSV/PDF export functionality
- CLI bulk import completion
