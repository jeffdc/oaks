# Oak Compendium CLI

A command-line tool for managing taxonomic and identification data for oak (Quercus) species.

## Features

- **Source-Attributed Data**: Every data point is linked to a source for traceability
- **Multi-Source Support**: Combine data from iNaturalist, Oaks of the World, and personal observations
- **Bear App Integration**: Import field notes from Bear (iOS/macOS)
- **$EDITOR Integration**: Edit entries in YAML format using your preferred editor
- **SQLite Backend**: Single-file database, no configuration required

## Installation

### Prerequisites

- Go 1.21+ (uses go-sqlite3 which requires CGO)

### Build from Source

```bash
cd cli
go build -o oak .
```

Optionally install to your Go bin:

```bash
go install .
```

## Quick Start

### View Available Commands

```bash
./oak --help
```

### Common Workflows

**Browse species:**
```bash
./oak find alba              # Search for species
./oak find "white oak"       # Search in common names
```

**Import from Bear:**
```bash
./oak import-bear --dry-run  # Preview what would be imported
./oak import-bear            # Import notes from Bear app
```

**Export for web:**
```bash
./oak export ../web/public/quercus_data.json
```

## Commands

### Species Management

| Command | Description |
|---------|-------------|
| `oak new <name>` | Create a new species entry (opens $EDITOR) |
| `oak edit <name>` | Edit an existing entry |
| `oak delete <name>` | Delete an entry (with confirmation) |
| `oak find <query>` | Search for species or sources |
| `oak note <species>` | Add/edit source-attributed notes |

### Import Commands

| Command | Description |
|---------|-------------|
| `oak import-bear` | Import notes from Bear app (Source 3) |
| `oak import-bulk <file>` | Bulk import from YAML file |
| `oak import-oaksoftheworld <file>` | Import scraped data (Source 2) |

### Export Commands

| Command | Description |
|---------|-------------|
| `oak export <file>` | Export database to JSON for web app |
| `oak generate-bear-notes` | Generate markdown templates for Bear |

### Source Management

| Command | Description |
|---------|-------------|
| `oak source list` | List all registered sources |
| `oak source new` | Create a new source |
| `oak source edit <id>` | Edit a source |
| `oak source show <id>` | Show source details |

### Taxonomy Management

| Command | Description |
|---------|-------------|
| `oak taxa list` | List taxonomy hierarchy |
| `oak taxa import <file>` | Import taxonomy from YAML |

### Schema Management

| Command | Description |
|---------|-------------|
| `oak add-value <field> <value>` | Add enumeration value to schema |
| `oak remove-from-array <species> <field> <value>` | Remove value from array field |

## Data Sources

The CLI manages three data sources:

| ID | Name | Type | Description |
|----|------|------|-------------|
| 1 | iNaturalist | Website | Authoritative taxonomy and species list |
| 2 | Oaks of the World | Website | Morphological descriptions |
| 3 | Oak Compendium | Personal Observation | Field notes from Bear app |

## Configuration

### Database Location

Default: `oak_compendium.db` in current directory

Override with `-d` flag:
```bash
./oak -d /path/to/database.db find alba
```

### Schema Location

Default: `schema/oak_schema.json`

Override with `-s` flag:
```bash
./oak -s /path/to/schema.json new "Quercus alba"
```

### Editor

Set via `$EDITOR` environment variable (defaults to `vi`):
```bash
export EDITOR=vim
./oak edit "alba"
```

## Project Structure

```
cli/
├── main.go              # Entry point
├── cmd/                 # Cobra command implementations
│   ├── root.go          # Root command and global flags
│   ├── find.go          # Search command
│   ├── new.go           # Create entry
│   ├── edit.go          # Edit entry
│   ├── delete.go        # Delete entry
│   ├── note.go          # Add/edit notes
│   ├── export.go        # JSON export
│   ├── import_bear.go   # Bear app import
│   ├── import_bulk.go   # Bulk YAML import
│   ├── import_oaksoftheworld.go
│   ├── generate_bear_notes.go
│   ├── source.go        # Source subcommands
│   ├── taxa.go          # Taxonomy subcommands
│   ├── add_value.go     # Schema management
│   └── remove_from_array.go
├── internal/
│   ├── db/              # Database layer (repository pattern)
│   ├── models/          # Data structures
│   ├── schema/          # JSON schema validation
│   └── editor/          # $EDITOR workflow
├── data/                # Seed files
│   ├── quercus-taxonomy.yaml
│   └── quercus-species.yaml
├── schema/
│   └── oak_schema.json  # Validation schema
└── oak_compendium.db    # SQLite database (committed to repo)
```

## Technical Details

- **Language**: Go
- **Database**: SQLite via `go-sqlite3`
- **CLI Framework**: Cobra
- **Validation**: JSON Schema via `jsonschema`
- **Serialization**: YAML via `yaml.v3`

## Development

### Building

```bash
go build -o oak .
```

### Testing

```bash
go test ./...              # Run all tests
go test ./... -v           # Verbose output
go test ./... -cover       # With coverage report
go test -run TestName      # Run specific test
```

Test coverage includes:
- `internal/db/`: Database operations (CRUD, search, transactions)
- `internal/models/`: Model serialization and round-trip tests
- `internal/schema/`: JSON schema validation
- `internal/editor/`: Frontmatter parsing, section extraction

### Adding a New Command

1. Create `cmd/mycommand.go`
2. Define the command using Cobra
3. Register it in `init()` with `rootCmd.AddCommand()`
