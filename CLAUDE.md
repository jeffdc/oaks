# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Quercus Database is a comprehensive database and query tool for oak (Quercus) species and their hybrids. The project consists of three main components:

1. **Python Scraper** - Extracts oak species data from oaksoftheworld.fr
2. **Web Application** - Modern Svelte 5 PWA for browsing species data
3. **CLI Tool** - Rust-based command-line tool for managing taxonomic data (in development)

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
├── cli/                      # Rust CLI tool (in development)
│   ├── src/                  # Rust source files
│   ├── Cargo.toml            # clap, rusqlite, serde, jsonschema
│   └── docs/oak_cli.md       # Comprehensive CLI specification
├── browse.html               # Legacy static HTML browser
├── quercus.db                # Canonical SQLite database (managed by CLI)
└── quercus_data.json         # Legacy JSON export (for browse.html)
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

**Important**: The web app's `vite.config.js` includes a custom plugin that copies `../quercus.db` (SQLite database) to `public/` during build. Legacy support also copies `../quercus_data.json` for fallback. See `web/CLAUDE.md` for detailed architecture.

### CLI Tool Workflow

```bash
cd cli

# Build
cargo build

# Run with cargo
cargo run -- <subcommand>

# Install locally
cargo install --path .
```

**Note**: The CLI is in early development. See `cli/docs/oak_cli.md` for the complete specification.

## Data Flow Architecture

```
oaksoftheworld.fr (source)
        ↓
    scraper.py (extracts)
        ↓
intermediate JSON/JSONL (scraped data)
        ↓
    CLI tool (import & manage)
        ↓
quercus.db (SQLite - canonical database)
        ↓
    ┌───────┴───────────┐
    ↓                   ↓
CLI export         Build process
    ↓                   ↓
JSON (legacy)      Copy quercus.db
    ↓                   ↓
browse.html        web/ (Svelte PWA)
                        ↓
                wa-sqlite (WASM)
                        ↓
                User's browser (offline SQLite queries)
```

**Critical**: The CLI-managed SQLite database (`quercus.db`) is the canonical source of truth. The scraper outputs intermediate files that the CLI imports. The web app uses wa-sqlite to run the database directly in the browser with full offline query capabilities.

## Architecture Decisions

### SQLite for Offline PWA (Decision: 2025-12-14)

**Decision**: Use SQLite (via wa-sqlite WASM) as the primary data format for the web application instead of JSON.

**Rationale**:
- **Performance**: SQLite queries are 2-60x faster than JSON parsing for structured data operations. Real-world tests show startup time improvements from 30 minutes (JSON) to 10 seconds (SQLite) and 73% file size reduction.
- **Offline Queries**: Enable complex filtering, searching, and joins entirely client-side without network dependency.
- **Scalability**: Handles millions of rows efficiently. Current dataset is ~500 species but expected to grow.
- **Browser Support**: Excellent coverage (Chrome 102+, Firefox 111+, Safari 16.4+) = 95%+ market share.
- **Modern Standard**: OPFS (Origin Private File System) is the future of browser-based data persistence.

**Implementation**:
- **Library**: [wa-sqlite](https://github.com/rhashimoto/wa-sqlite) with OPFSCoopSyncVFS backend
- **Persistence**: OPFS for modern browsers, IndexedDB fallback
- **Bundle Size**: ~200KB (WASM + JS wrapper)
- **Deployment**: Build process copies `quercus.db` to web app, service worker caches it
- **Fallback**: Optional JSON export for legacy browser support (feature detection)

**Migration Path**:
1. Current: JSON-based web app (temporary)
2. Next: Implement wa-sqlite in parallel with feature detection
3. Future: Deprecate JSON when SQLite coverage is sufficient

**Trade-offs Accepted**:
- Slightly larger initial bundle (~200KB WASM)
- Requires modern browser (Safari 16.4+, Chrome 102+, Firefox 111+)
- Some limitations in Safari incognito mode (acceptable for field use case)

## Data Structure

### Species Object Schema

```json
{
  "name": "alba",              // Species name (WITHOUT "Quercus" prefix)
  "is_hybrid": false,
  "author": "L. 1753",
  "synonyms": [
    {"name": "...", "author": "..."}
  ],
  "local_names": ["white oak", "eastern white oak"],
  "range": "Eastern North America; 0 to 1600 m",
  "growth_habit": "reaches 25 m high...",
  "leaves": "8-20 cm long...",
  "flowers": "...",
  "fruits": "...",
  "bark_twigs_buds": "...",
  "hardiness_habitat": "...",
  "taxonomy": {
    "subgenus": "Quercus",
    "section": "Quercus",
    "series": "Albae"
  },
  "conservation_status": "...",
  "subspecies_varieties": [...],
  "hybrids": ["Quercus × bebbiana"],  // Bidirectional relationships
  "url": "https://oaksoftheworld.fr/...",

  // Hybrid-specific fields:
  "parent_formula": "alba x macrocarpa",  // Only for hybrids
  "parent1": "Quercus alba",              // Only for hybrids
  "parent2": "Quercus macrocarpa"         // Only for hybrids
}
```

**Important Conventions**:
- Species names stored WITHOUT "Quercus" prefix (e.g., "alba" not "Quercus alba")
- Hybrid indicator: `is_hybrid` boolean + `×` in name
- All fields are optional except `name` and `is_hybrid`
- Empty/missing fields represented as `null` or omitted
- Hybrids list is bidirectional (maintained by `build_hybrid_relationships()` in `parser.py`)

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
- Parses taxonomy (subgenus/section/series)
- Identifies hybrid parents from formulas like "alba x macrocarpa"
- Function: `build_hybrid_relationships()` creates bidirectional links

**utils.py** - Infrastructure:
- `fetch_page()`: HTTP with caching and rate limiting (0.5s delay)
- Progress tracking: `load_progress()`, `save_progress()`
- Cache management: `html_cache/` directory
- Inconsistency logging: `data_inconsistencies.log`

### Scraper State Management

**Progress File**: `scrapers/oaksoftheworld/scraper_progress.json`
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

The Rust CLI (`oak`) follows a sophisticated architecture for managing taxonomic data with strict validation and source attribution. See `cli/docs/oak_cli.md` for full specification.

### Core Concepts

**Source-Attributed Data**: Every data point is linked to a specific source. Conflicts only occur when updating data from the *same* source.

**Editor-Based Workflow**: Uses `$EDITOR` for structured YAML editing with strict schema validation.

### Key Commands (Planned)

```bash
oak new                          # Create new entry (opens $EDITOR)
oak edit <name>                  # Edit existing entry
oak find <query> [-i]            # Search (use -i for pipeline-friendly IDs)
oak source new                   # Create source entry
oak import-bulk <file> --source-id <ID>  # Bulk import with conflict resolution
```

**Technology Stack**:
- Language: Rust (latest stable)
- Database: SQLite via `rusqlite`
- CLI Framework: `clap`
- Validation: JSON Schema via `jsonschema` crate
- Serialization: YAML via `serde_yaml`

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

### Rust (CLI)

```bash
cd cli
cargo build
```

## Important Conventions

### File Naming
- Python: `snake_case.py`
- JavaScript: `PascalCase.svelte`, `camelCase.js`
- Rust: `snake_case.rs`

### Code Style
- **Python**: PEP 8, docstrings on functions, meaningful variable names
- **JavaScript**: 2-space indent, see `web/CLAUDE.md` for Svelte conventions
- **Rust**: `cargo fmt`, strict type safety, Repository Pattern for DB access

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
cargo test
```

## Data Validation

### Scraper Output Validation
After running scraper, verify:
1. `quercus_data.json` exists in root directory
2. JSON is valid: `python3 -m json.tool quercus_data.json > /dev/null`
3. Check `data_inconsistencies.log` for taxonomic issues
4. Test in web app: `cd web && npm run dev`

### Web App Data Loading
The web app fetches `/quercus_data.json` at startup. If schema changes:
- Update display logic in `SpeciesDetail.svelte`
- Update search logic in `dataStore.js` if needed
- No code changes required for new optional fields

## Performance Considerations

### Scraper
- Rate limiting: 0.5 second delay between requests (hardcoded in `utils.py`)
- Caching: HTML pages cached in `html_cache/` to avoid re-fetching
- Use `--no-cache` flag only for testing/debugging

### Web App
- Single JSON fetch on load (~1.2MB for ~500 species)
- Client-side filtering (fast enough for current dataset)
- Service worker caches everything for offline use
- No lazy loading needed currently

## Troubleshooting

### Scraper Issues
- **SSL errors**: Use `--no-ssl-verify` flag (not recommended)
- **Stuck progress**: Check `scraper_progress.json`, use `--restart` to clear
- **Missing data**: Check `data_inconsistencies.log` for parsing issues
- **Cache problems**: Delete `html_cache/` directory or use `--no-cache`

### Web App Issues
- **Data not loading**: Check browser console, verify `quercus_data.json` exists
- **PWA not updating**: Clear service worker cache in browser DevTools
- **Build fails**: Delete `node_modules/` and `package-lock.json`, run `npm install`

### CLI Issues
- **Build errors**: Run `cargo clean && cargo build`
- **Database locked**: Only one process can access SQLite at a time

## Future Enhancements

See `README.md` for project roadmap. Key planned features:
- Geographic filtering and map view
- Taxonomy tree visualization
- Image gallery integration
- Advanced search filters (by section, range, etc.)
- CSV/PDF export functionality
- CLI bulk import completion
