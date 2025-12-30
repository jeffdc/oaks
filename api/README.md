# Oak Compendium API Server

A REST API server for the Oak Compendium database, providing remote access to oak species taxonomic data.

## Quick Start

```bash
cd api

# Build
make build

# Run locally (uses ../cli/oak_compendium.db)
make run
```

The server will start on `http://localhost:8080`.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OAK_DB_PATH` | `./oak_compendium.db` | Path to SQLite database |
| `OAK_PORT` | `8080` | HTTP port to listen on |
| `OAK_API_KEY` | (auto-generated) | API key for authentication |

The API key is loaded from (in order):
1. `OAK_API_KEY` environment variable
2. `~/.oak/api_key` file
3. Auto-generated on first run

## API Endpoints

### Health Check

```
GET /api/v1/health
```

Returns server health status and version information.

### Species

```
GET    /api/v1/species              # List species (with pagination)
GET    /api/v1/species/:name        # Get species by name
POST   /api/v1/species              # Create species
PUT    /api/v1/species/:name        # Update species
DELETE /api/v1/species/:name        # Delete species
```

Query parameters for listing:
- `limit` - Maximum results (default: 50)
- `offset` - Pagination offset
- `q` - Search query
- `subgenus` - Filter by subgenus
- `section` - Filter by section

### Taxa

```
GET    /api/v1/taxa                 # List taxonomy entries
GET    /api/v1/taxa/:name           # Get taxon by name
POST   /api/v1/taxa                 # Create taxon
PUT    /api/v1/taxa/:name           # Update taxon
DELETE /api/v1/taxa/:name           # Delete taxon
```

### Sources

```
GET    /api/v1/sources              # List data sources
GET    /api/v1/sources/:id          # Get source by ID
POST   /api/v1/sources              # Create source
PUT    /api/v1/sources/:id          # Update source
DELETE /api/v1/sources/:id          # Delete source
```

### Export

```
GET    /api/v1/export               # Export database as JSON
```

## Authentication

All endpoints (except health check) require API key authentication.

Include the API key in the `Authorization` header:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
     https://oak-compendium-api.fly.dev/api/v1/species/alba
```

### Generating an API Key

```bash
# Generate a new API key
./oak-api --generate-key

# Output:
# New API key generated and saved to ~/.oak/api_key
# API Key: oak_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Docker Deployment

### Build Image

```bash
make docker-build

# Or directly:
docker build -t oak-api:latest -f Dockerfile ..
```

### Run Container

```bash
docker run -d \
  -p 8080:8080 \
  -v /path/to/data:/data \
  -e OAK_DB_PATH=/data/oak_compendium.db \
  -e OAK_API_KEY=your-api-key \
  oak-api:latest
```

## Fly.io Deployment

The API is deployed to Fly.io at https://oak-compendium-api.fly.dev

### Initial Setup

```bash
# Create app (already done)
fly apps create oak-compendium-api --region iad

# Create volume for database
fly volumes create oak_data --size 1 --region iad --app oak-compendium-api

# Set API key secret
fly secrets set OAK_API_KEY=your-api-key --app oak-compendium-api

# Deploy
fly deploy --app oak-compendium-api
```

### Database Seeding

```bash
# Upload database to volume
fly ssh sftp put cli/oak_compendium.db /data/oak_compendium.db --app oak-compendium-api

# Restart to pick up new database
fly apps restart oak-compendium-api
```

### Updating Database

Fly's SFTP doesn't overwrite files, so remove first:

```bash
fly ssh console -C "rm /data/oak_compendium.db" --app oak-compendium-api
fly ssh sftp put cli/oak_compendium.db /data/oak_compendium.db --app oak-compendium-api
fly apps restart oak-compendium-api
```

### Monitoring

```bash
# Check status
fly status --app oak-compendium-api

# View logs
fly logs --app oak-compendium-api

# SSH into container
fly ssh console --app oak-compendium-api
```

## Development

### Prerequisites

- Go 1.21+ (requires CGO for sqlite)
- golangci-lint (optional, for linting)

### Build

```bash
make build
```

### Run Tests

```bash
make test
make test-coverage  # With HTML coverage report
```

### Lint

```bash
make lint
```

### Project Structure

```
api/
├── main.go               # Server entry point
├── internal/
│   ├── handlers/         # HTTP request handlers
│   │   ├── server.go     # Server setup and routing
│   │   ├── species.go    # Species endpoints
│   │   ├── taxa.go       # Taxonomy endpoints
│   │   ├── sources.go    # Sources endpoints
│   │   ├── export.go     # Export endpoint
│   │   ├── health.go     # Health check endpoint
│   │   ├── auth.go       # API key authentication
│   │   └── middleware.go # Request logging, etc.
│   ├── db/               # Database layer
│   ├── models/           # Data structures
│   └── export/           # JSON export logic
├── go.mod                # Go module definition
├── Makefile              # Build targets
└── Dockerfile            # Container build
```

## Version Compatibility

The API includes version information in the health endpoint:

```json
{
  "status": "ok",
  "version": {
    "api": "1.0.0",
    "min_client": "1.0.0"
  }
}
```

The CLI checks `min_client` version on connection and warns if the CLI version is too old. Use `--skip-version-check` to bypass this check.
