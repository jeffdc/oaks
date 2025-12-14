# Oak Compendium CLI Tool

A powerful command-line interface for managing taxonomic and identification data for the Oak Compendium database.

## Features

- **Source-Attributed Data**: Every data point is explicitly tied to a source, ensuring data integrity and traceability
- **Strict Validation**: JSON schema validation with enumerated field values prevents bad data from entering the system
- **$EDITOR Integration**: Edit entries using your preferred text editor (YAML format)
- **Interactive Conflict Resolution**: Smart merging handles conflicts when importing bulk data
- **Pipeline-Friendly**: `--id-only` flag for seamless integration with shell scripts and tools like `xargs`
- **SQLite Backend**: Fast, reliable, single-file database with zero configuration

## Installation

### Prerequisites

- Rust (latest stable version)
- SQLite (bundled with the binary)

### Build from Source

```bash
cd cli
cargo build --release
```

The compiled binary will be at `target/release/oak`.

You can optionally install it system-wide:

```bash
cargo install --path .
```

## Quick Start

### 1. Create a Source

Before adding oak data, you need to create at least one source:

```bash
oak source new
```

This will prompt you for source details and output the `source_id` to stdout.

### 2. Create an Oak Entry

```bash
oak new "Quercus robur"
```

This opens your `$EDITOR` with a YAML template. Add data points with source attribution:

```yaml
scientific_name: Quercus robur
common_names:
  - value: English Oak
    source_id: flora_britannica
    page_number: "245"
leaf_shape:
  - value: lobed
    source_id: flora_britannica
leaf_color:
  - value: dark green
    source_id: field_observations_2024
```

### 3. Search and Query

```bash
# Human-readable output
oak find robur

# Pipeline mode (IDs only)
oak find robur --id-only
```

## Commands

### Core Library Management

| Command | Description | Example |
|---------|-------------|---------|
| `oak new <name>` | Create a new Oak entry | `oak new "Quercus alba"` |
| `oak edit <name>` | Modify an existing entry | `oak edit "Quercus robur"` |
| `oak delete <name>` | Remove an entry (with confirmation) | `oak delete "Quercus alba"` |

### Search and Discovery

| Command | Description | Example |
|---------|-------------|---------|
| `oak find <query>` | Search entries and sources | `oak find robur` |
| `oak find <query> -i` | Output IDs only (for piping) | `oak find robur -i \| xargs -I {} oak edit {}` |
| `oak find <query> -t oak` | Search only oak entries | `oak find alba -t oak` |
| `oak find <query> -t source` | Search only sources | `oak find flora -t source` |

### Source Management

| Command | Description | Example |
|---------|-------------|---------|
| `oak source new` | Create a new source | `oak source new` |
| `oak source edit <id>` | Modify a source | `oak source edit flora_britannica` |
| `oak source list` | Display all sources | `oak source list` |

### Schema Management

| Command | Description | Example |
|---------|-------------|---------|
| `oak add-value <field> <value>` | Add enumeration value | `oak add-value leaf_shape "deeply-lobed"` |

### Bulk Import

| Command | Description | Example |
|---------|-------------|---------|
| `oak import-bulk <file> --source-id <id>` | Import data from YAML/JSON file | `oak import-bulk data.yaml --source-id my_source` |

## Data Architecture

### Source-Attributed Data Points

The Oak Compendium uses a unique architecture where **conflicts are only possible when updating data from the same source**:

- ✅ **Not a Conflict**: Same field, different sources
  ```yaml
  leaf_color:
    - value: green
      source_id: book_a
    - value: dark green
      source_id: book_b
  ```

- ⚠️ **Conflict**: Same field, same source, different value
  ```
  Database has:  leaf_color = "green" (source: book_a)
  Import has:    leaf_color = "dark green" (source: book_a)
  ```

### Conflict Resolution

When importing bulk data, conflicts are resolved interactively:

```
Conflict for Quercus robur, field: leaf_color (Source: flora_2024)
[1] Database Value: 'green'
[2] Imported Value: 'dark green'
[3] Merge Manually (Open Editor for this specific entry)
[S] Skip this entry and continue
> Enter choice (1/2/3/S):
```

## Schema and Validation

The tool uses a JSON schema file (`schema/oak_schema.json`) to validate entries. Enumerated fields have allowed values:

- `leaf_shape`: lobed, entire, serrated, toothed
- `leaf_color`: green, dark green, blue-green, yellow-green
- `bud_shape`: ovoid, conical, rounded
- `bark_texture`: rough, furrowed, scaly, smooth

Add new values with:

```bash
oak add-value leaf_shape "pinnately-lobed"
```

## Configuration

### Database Location

Default: `oak_compendium.db` in the current directory

Override:
```bash
oak -d /path/to/database.db <command>
```

### Schema Location

Default: `schema/oak_schema.json`

Override:
```bash
oak -s /path/to/schema.json <command>
```

### Editor

The tool respects your `$EDITOR` environment variable. If not set, defaults to `vi`.

```bash
export EDITOR=nano  # or vim, emacs, code, etc.
```

## Pipeline Examples

### Batch edit all entries matching a pattern

```bash
oak find "Quercus" --id-only | while read name; do
  oak edit "$name"
done
```

### Export all source IDs

```bash
oak find "" --id-only -t source > all_sources.txt
```

### Delete multiple entries

```bash
# Be careful with this!
oak find "test_" --id-only | xargs -I {} oak delete {}
```

## Development

### Project Structure

```
cli/
├── src/
│   ├── main.rs           # CLI entry point
│   ├── models.rs         # Data structures
│   ├── db.rs             # Database layer
│   ├── schema.rs         # Validation
│   ├── editor.rs         # $EDITOR workflow
│   └── commands/         # Command implementations
├── schema/
│   └── oak_schema.json   # Validation schema
└── Cargo.toml
```

### Running Tests

```bash
cargo test
```

### Building for Release

```bash
cargo build --release
strip target/release/oak  # Optional: reduce binary size
```

## Technical Details

- **Language**: Rust (edition 2021)
- **Database**: SQLite via `rusqlite`
- **CLI Framework**: `clap` with derive macros
- **Serialization**: `serde` + `serde_yaml`
- **Validation**: `jsonschema`
- **Interactive Prompts**: `dialoguer`

## License

See LICENSE file in the project root.
