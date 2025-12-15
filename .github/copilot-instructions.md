# GitHub Copilot Instructions for Quercus Database

## Project Overview

The Quercus Database is a comprehensive database and query tool for oak (Quercus) species and their hybrids. It combines a Python web scraper, a Svelte 5 PWA, and a Rust CLI tool for managing taxonomic data.

**Key Features:**
- Web scraper for oaksoftheworld.fr
- Offline-first PWA with IndexedDB storage
- Source-attributed taxonomic data model
- Comprehensive species information (morphology, taxonomy, hybrids)

## Tech Stack

- **Python Scraper**: BeautifulSoup4, requests, lxml
- **Web App**: Svelte 5 (runes), Vite, Tailwind 4, IndexedDB (Dexie.js)
- **CLI**: Rust (in development), SQLite, clap, serde
- **Testing**: Standard frameworks for each language
- **CI/CD**: GitHub Actions (planned)

## Coding Guidelines

### Python (Scraper)
- Follow PEP 8 style
- Add docstrings to functions
- Use meaningful variable names
- Cache HTML to avoid re-fetching
- Log data inconsistencies to `data_inconsistencies.log`

### JavaScript/Svelte (Web App)
- 2-space indentation
- Use Svelte 5 runes syntax
- Store state in Svelte stores (`dataStore.js`)
- Follow component patterns in `web/CLAUDE.md`
- Use Tailwind 4 utilities for styling

### Rust (CLI)
- Run `cargo fmt` before committing
- Use strict type safety
- Follow Repository Pattern for DB access
- See `cli/docs/oak_cli.md` for specifications

### Git Workflow
- This project uses **bd (beads)** for issue tracking
- Always commit `.beads/issues.jsonl` with code changes
- Run `bd sync --from-main` at end of sessions (on ephemeral branches)
- Commit messages: Present tense, imperative mood

## Issue Tracking with bd

**CRITICAL**: This project uses **bd** for ALL task tracking. Do NOT create markdown TODO lists.

### Essential Commands

```bash
# Find work
bd ready --json                    # Unblocked issues
bd list --status open --json       # All open issues

# Create and manage
bd create "Title" -t bug|feature|task -p 0-4 --json
bd create "Subtask" --parent <epic-id> --json
bd update <id> --status in_progress --json
bd close <id> --reason "Done" --json

# Dependencies
bd dep add <issue> <depends-on>    # Issue depends on depends-on

# Sync (at end of session)
bd sync --from-main
```

### Workflow

1. **Check ready work**: `bd ready --json`
2. **Claim task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** `bd create "Found bug" -p 1 --deps discovered-from:<parent-id> --json`
5. **Complete**: `bd close <id> --reason "Done" --json`
6. **Sync**: `bd sync --from-main`

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

## Project Structure

```
oaks/
├── scrapers/oaksoftheworld/  # Python web scraper
│   ├── scraper.py            # Main orchestration
│   ├── name_parser.py        # Parse species list
│   ├── parser.py             # Parse individual pages
│   └── utils.py              # Caching, HTTP, progress
├── web/                      # Svelte 5 PWA
│   ├── src/                  # Components and stores
│   └── vite.config.js        # Build config (copies JSON)
├── cli/                      # Rust CLI (in development)
│   ├── src/                  # Rust source
│   └── docs/oak_cli.md       # CLI specification
├── quercus.db                # Canonical SQLite DB (CLI-managed)
├── quercus_data.json         # JSON export for web app
└── .beads/
    ├── beads.db              # Issue tracking DB (DO NOT COMMIT)
    └── issues.jsonl          # Git-synced issues
```

## Key Documentation

- **CLAUDE.md** - Comprehensive project guide (architecture, workflows, conventions)
- **web/CLAUDE.md** - Detailed web app architecture
- **cli/docs/oak_cli.md** - CLI tool specification
- **AGENTS.md** - AI agent workflow with bd

## Data Flow

```
oaksoftheworld.fr
    ↓ (scraper)
intermediate JSON
    ↓ (CLI import)
quercus.db (SQLite - canonical)
    ↓ (CLI export)
quercus_data.json
    ↓ (web app load)
IndexedDB (offline queries)
```

## Common Tasks

### Running the Scraper
```bash
cd scrapers/oaksoftheworld
source ../../venv/bin/activate
python3 scraper.py                # Resume from last position
python3 scraper.py --restart      # Start fresh
python3 scraper.py --test         # First 50 species
```

### Web App Development
```bash
cd web
npm install
npm run dev        # http://localhost:5173
npm run build      # Production build
```

### CLI Development
```bash
cd cli
cargo build
cargo run -- <subcommand>
cargo test
```

## CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

## Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic bd commands
- ✅ Run `bd sync --from-main` at end of sessions
- ✅ Commit `.beads/issues.jsonl` with code changes
- ✅ Follow language-specific style guides
- ✅ Run `bd <cmd> --help` to discover available flags
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT commit `.beads/beads.db`
- ❌ Do NOT add emojis unless user requests them

---

**For detailed beads workflow, see [AGENTS.md](../AGENTS.md)**
