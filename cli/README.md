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

### Embedded vs Remote Mode

The CLI uses an HTTP API client for all operations. It supports two modes:

- **Embedded mode** (default): Starts an in-process API server that operates on the local SQLite database. Commands communicate with this server via HTTP on localhost. This provides a unified code path regardless of mode.

- **Remote mode**: Connects to an external API server (e.g., production on Fly.io) via HTTPS. Requires profile configuration.

By default, the CLI uses embedded mode. To use remote mode, configure a profile.

### Profile Configuration

Create `~/.oak/config.yaml` to configure API profiles:

```yaml
# ~/.oak/config.yaml

profiles:
  # Production API
  prod:
    url: https://oak-compendium-api.fly.dev
    key: your-api-key-here

  # Local development server
  local-server:
    url: http://localhost:8080
    key: dev-key

# Uncomment to default to a profile instead of local mode
# default_profile: prod
```

### Profile Resolution Order

The CLI resolves which profile to use in this order:

1. `OAK_API_URL` + `OAK_API_KEY` environment variables (legacy, overrides all)
2. `--profile <name>` flag
3. `OAK_PROFILE` environment variable
4. `default_profile` from config file
5. No profile → local database mode (safe default)

### Mode Flags

| Flag | Description |
|------|-------------|
| `--profile <name>` | Use the specified remote API profile from config |
| `--local` | Force embedded mode (use local database, ignore any default_profile) |
| `--remote` | Force remote mode (errors if no profile configured) |
| `--skip-version-check` | Skip API version compatibility check (remote mode only) |

### Mode Examples

```bash
# Default: embedded mode (uses local database)
./oak find alba

# Use a specific remote profile
./oak --profile prod find alba

# Force embedded mode even if default_profile is set in config
./oak --local find alba

# Check which profile is active and current mode
./oak config show

# List all configured profiles
./oak config list
```

### Destructive Operations

When operating against a remote profile, destructive operations (create, edit, delete) require confirmation:

```
Delete "alba" on [prod]? (y/N):
```

### Database Location (Embedded Mode)

Default: `oak_compendium.db` in current directory

Override with `-d` flag:
```bash
./oak -d /path/to/database.db find alba
```

Note: The `-d` flag only applies in embedded mode. In remote mode, the database is managed by the API server.

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
│   ├── root.go          # Root command, global flags, mode resolution
│   ├── config.go        # Config show/list commands
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
│   ├── client/          # HTTP client for API (used by all commands)
│   ├── config/          # Profile configuration management
│   ├── embedded/        # Embedded API server wrapper
│   ├── models/          # Data structures
│   ├── editor/          # $EDITOR workflow
│   └── schema/          # JSON schema validation
├── data/                # Seed files
│   ├── quercus-taxonomy.yaml
│   └── quercus-species.yaml
├── schema/
│   └── oak_schema.json  # Validation schema
└── oak_compendium.db    # SQLite database (committed to repo)
```

### Architecture Note

All CLI commands use the `internal/client` package for data operations. In embedded mode, the client communicates with an in-process API server (started automatically). In remote mode, it communicates with an external API server. This unified architecture ensures consistent behavior across modes.

## Technical Details

- **Language**: Go
- **CLI Framework**: Cobra
- **HTTP Client**: Built-in net/http with retry logic
- **Validation**: JSON Schema via `jsonschema`
- **Serialization**: YAML via `yaml.v3`
- **Database** (embedded mode): SQLite via `go-sqlite3` (in api module)

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
- `internal/client/`: API client operations (HTTP requests, error handling, retries)
- `internal/models/`: Model serialization and round-trip tests
- `internal/schema/`: JSON schema validation
- `internal/editor/`: Frontmatter parsing, section extraction
- `cmd/`: Integration tests for embedded and remote modes

### Adding a New Command

1. Create `cmd/mycommand.go`
2. Define the command using Cobra
3. Register it in `init()` with `rootCmd.AddCommand()`

## Deployment (Fly.io)

The Oak Compendium API is deployed to Fly.io at https://oak-compendium-api.fly.dev

### Initial Database Seeding

To copy the local database to the production Fly.io volume:

```bash
# Remove existing empty database (if present)
fly ssh console -C "rm /data/oak_compendium.db" --app oak-compendium-api

# Upload the populated database
fly ssh sftp put cli/oak_compendium.db /data/oak_compendium.db --app oak-compendium-api

# Restart the app to pick up the new database
fly apps restart oak-compendium-api

# Verify the data
curl -s "https://oak-compendium-api.fly.dev/api/v1/species?limit=3"
```

### Updating Production Data

For subsequent database updates:

```bash
# Remove existing database
fly ssh console -C "rm /data/oak_compendium.db" --app oak-compendium-api

# Upload new version
fly ssh sftp put cli/oak_compendium.db /data/oak_compendium.db --app oak-compendium-api

# Restart app
fly apps restart oak-compendium-api
```

Note: Fly's SFTP doesn't overwrite files, so you must remove the existing file first.

### Verifying Production

```bash
# Check app status
fly status --app oak-compendium-api

# Check database record count
fly ssh console -C "sqlite3 /data/oak_compendium.db 'SELECT COUNT(*) FROM oak_entries'" --app oak-compendium-api

# Test API endpoints
curl https://oak-compendium-api.fly.dev/api/v1/species/alba
```
