# Change: Split CLI and API Server into Separate Binaries

## Why

The CLI (`oak`) and API server are currently bundled in a single Go binary. This made sense during initial development, but now presents issues:

1. **Deployment bloat**: The Fly.io container ships the entire CLI (~15MB binary) but only uses `oak serve`. CLI commands like `import-bear`, `generate-bear-notes`, schema validation, and editor integration are unused in production.

2. **Tight coupling**: CLI commands that could operate remotely (create, update, delete species) are hardcoded to use local database. Users cannot manage the deployed API database without SSH access.

3. **Development friction**: Changes to CLI commands (e.g., import logic) trigger API server rebuilds. Changes to API endpoints require full CLI rebuild.

4. **Dependency sprawl**: The API server carries cobra, jsonschema validation, YAML parsing, and editor utilities it doesn't need.

## What Changes

### Repository Structure
- **ADDED**: `api/` - New top-level directory for API server
- **MODIFIED**: `cli/` - Becomes CLI-only, gains API client for remote operations
- **MODIFIED**: `cli/internal/` - Shared packages move to `api/internal/` or new `pkg/` directory

### API Server (`api/`)
- **ADDED**: `api/main.go` - Standalone API server binary
- **MOVED**: `cli/internal/api/` → `api/internal/handlers/`
- **MOVED**: `cli/internal/db/` → `api/internal/db/`
- **MOVED**: `cli/internal/models/` → `api/internal/models/` (or `pkg/models/`)
- **ADDED**: `api/Dockerfile` - Minimal server-only image
- **ADDED**: `api/go.mod` - Independent module (or workspace member)

### CLI (`cli/`)
- **ADDED**: `cli/internal/client/` - HTTP client for API server
- **MODIFIED**: Commands gain `--remote` flag or detect API configuration
- **REMOVED**: `cli/cmd/serve.go` - Server moved to `api/`
- **REMOVED**: `cli/internal/api/` - Handlers moved to `api/`
- **ADDED**: Configuration for API URL and key (`~/.oak/config.yaml` or env vars)

### Deployment
- **MODIFIED**: `fly.toml` → references `api/Dockerfile`
- **MODIFIED**: `.github/workflows/deploy-api.yml` → builds from `api/` directory

## Impact

- **Affected specs**: api-server (no functional changes, just reorganization)
- **Affected code**: All of `cli/` and new `api/` directory
- **Breaking changes**: None for API consumers. CLI users gain remote capability.
- **Deployment**: Server binary shrinks significantly (~5MB vs ~15MB)

## Architecture After Change

```
oaks/
├── api/                      # API server (standalone)
│   ├── main.go
│   ├── go.mod
│   ├── Dockerfile
│   └── internal/
│       ├── handlers/         # HTTP handlers (from cli/internal/api/)
│       ├── db/               # Database access
│       └── models/           # Data models
├── cli/                      # CLI tool (uses API client for remote ops)
│   ├── main.go
│   ├── go.mod
│   ├── cmd/                  # Cobra commands
│   └── internal/
│       ├── client/           # NEW: API client
│       ├── db/               # Local DB access (kept for local-only commands)
│       ├── editor/           # Editor integration
│       └── schema/           # Schema validation
├── fly.toml                  # Points to api/Dockerfile
└── web/                      # (unchanged)
```

## Go Workspace vs Separate Modules

**Option A: Go Workspace (Recommended)**
- Single `go.work` file at repo root
- Shared types via `pkg/models/` directory
- Easier cross-module development
- `go.work`:
  ```
  go 1.24
  use ./api
  use ./cli
  ```

**Option B: Fully Separate Modules**
- Independent `go.mod` in each directory
- Types duplicated or vendored
- Cleaner separation but more maintenance

## CLI Remote Mode

When API is configured, CLI commands can operate remotely:

```bash
# Configure API endpoint
export OAK_API_URL=https://api.oakcompendium.com
export OAK_API_KEY=your-key-here

# Or via config file (~/.oak/config.yaml)
api:
  url: https://api.oakcompendium.com
  key: your-key-here

# Commands that support remote mode
oak find alba                  # Works locally or remotely
oak edit alba                  # Fetches from API, edits locally, PUTs back
oak new                        # Creates via API
oak delete alba                # Deletes via API

# Commands that remain local-only
oak import-bulk data/file.yaml # Bulk operations on local DB
oak export output.json         # Can export from API via GET /api/v1/export
oak taxa import file.yaml      # Local taxonomy operations
```
