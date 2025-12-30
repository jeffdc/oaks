# Change: Add CRUD API Server for Oak Compendium

## Why

The Oak Compendium currently relies on direct SQLite database access via the CLI, with data exported to static JSON for the web app. This works but has limitations:

- iOS app cannot access data without embedding a static file or complex sync
- Web app uses stale data (updated only when JSON is re-exported and deployed)
- No remote access for field use
- No way for multiple clients to share a single source of truth

A RESTful API server enables:
- Real-time data access for iOS app (in the field, on cellular)
- Potential web app migration from static JSON to live data
- Single authoritative database with proper access control
- Future extensibility (multi-user, third-party apps)

## Related Work

- **Depended on by**: OpenSpec change `replace-bear-with-ios-sync` (notes/iOS integration)
- **Existing work**: CLI already has full CRUD operations in `internal/db/db.go`

## What Changes

### CLI (`cli/`)
- **ADDED**: `oak serve` command to start API server
- **ADDED**: `cli/internal/api/` package with HTTP handlers
- **ADDED**: API key authentication middleware (write operations only)
- **ADDED**: CORS middleware for web app access
- **ADDED**: Rate limiting middleware (all endpoints)
- **ADDED**: Request logging middleware
- **ADDED**: Health check endpoint
- **ADDED**: Database backup endpoint (authenticated)
- **MODIFIED**: `go.mod` to add HTTP router dependency

### Infrastructure
- **ADDED**: `fly.toml` for Fly.io deployment
- **ADDED**: `Dockerfile` for containerized deployment
- **ADDED**: GitHub Actions workflow for deployment
- **ADDED**: Automated backup job (Fly.io scheduled machine or cron)
- **ADDED**: Custom domain configuration (`api.oakcompendium.com`)

### Documentation
- **ADDED**: API documentation (`cli/docs/api.md`)
- **MODIFIED**: `CLAUDE.md` to document API deployment
- **MODIFIED**: `openspec/project.md` with API details

## API Endpoints Overview

### Species (oak_entries)
```
GET    /api/v1/species              # List all species (paginated)
GET    /api/v1/species/:name        # Get species by scientific name
POST   /api/v1/species              # Create new species
PUT    /api/v1/species/:name        # Update species
DELETE /api/v1/species/:name        # Delete species
GET    /api/v1/species/search       # Search species
```

### Taxonomy (taxa)
```
GET    /api/v1/taxa                 # List all taxa (optionally by level)
GET    /api/v1/taxa/:level/:name    # Get specific taxon
POST   /api/v1/taxa                 # Create taxon
PUT    /api/v1/taxa/:level/:name    # Update taxon
DELETE /api/v1/taxa/:level/:name    # Delete taxon
```

### Sources
```
GET    /api/v1/sources              # List all sources
GET    /api/v1/sources/:id          # Get source by ID
POST   /api/v1/sources              # Create source
PUT    /api/v1/sources/:id          # Update source
DELETE /api/v1/sources/:id          # Delete source
```

### Species-Source Data (species_sources)
```
GET    /api/v1/species/:name/sources           # List all sources for a species
GET    /api/v1/species/:name/sources/:sourceId # Get specific source data
POST   /api/v1/species/:name/sources           # Add source data for species
PUT    /api/v1/species/:name/sources/:sourceId # Update source data
DELETE /api/v1/species/:name/sources/:sourceId # Delete source data
```

### Operational
```
GET    /api/v1/health               # Health check (public)
GET    /api/v1/health/ready         # Readiness check (public)
POST   /api/v1/backup               # Trigger backup (admin only)
GET    /api/v1/export               # Export full database as JSON
```

## Impact

- **Affected specs**: Creates new `api-server` capability
- **Affected code**:
  - `cli/cmd/serve.go` (new)
  - `cli/internal/api/` (new package)
  - `cli/go.mod` (dependencies)
  - `cli/Dockerfile` (new)
  - `fly.toml` (new)
- **Breaking changes**: None (additive change)
- **Security considerations**:
  - Read APIs: Public (no auth), protected by rate limiting
  - Write APIs: API key required, rate limited
  - All endpoints: TLS required, input validation, rate limiting

## Scope Boundaries

### In Scope
- Full CRUD for all four tables (oak_entries, taxa, sources, species_sources)
- API key authentication for write operations only (reads are public)
- Rate limiting on ALL endpoints (critical for public read APIs)
- Fly.io deployment with persistent storage
- Custom domain (`api.oakcompendium.com`)
- Automated database backups (provider TBD)
- Request logging
- CORS for web app
- Web app hybrid data loading (API when online, cached JSON offline)

### Out of Scope (future work)
- Multi-user authentication (OAuth, social login)
- WebSocket/real-time updates
- GraphQL alternative
- Full-text search (current LIKE queries are sufficient)
- Photo storage/CDN
- Analytics/usage tracking
