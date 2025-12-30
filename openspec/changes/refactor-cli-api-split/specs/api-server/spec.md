# api-server Specification (Delta)

## MODIFIED Requirements

### Requirement: API Server Startup
The API server SHALL be a standalone binary that starts an HTTP API server exposing CRUD operations for all database tables.

#### Scenario: Start server with defaults
- **WHEN** user runs the API server binary
- **THEN** server starts on port 8080
- **AND** server uses database at path from `OAK_DB_PATH` environment variable (default: `./oak_compendium.db`)
- **AND** API key is loaded from `OAK_API_KEY` environment variable or `~/.oak/api_key` file

#### Scenario: Start server with custom port
- **WHEN** `OAK_PORT` environment variable is set to `3000`
- **THEN** server starts on port 3000

#### Scenario: Start server with custom database
- **WHEN** `OAK_DB_PATH` environment variable is set to `/path/to/db.sqlite`
- **THEN** server uses the specified database file

#### Scenario: Generate API key
- **WHEN** user runs `oak-api --generate-key`
- **THEN** a new API key is generated and saved
- **AND** the new key is displayed to the user

### Requirement: Health Check Endpoints
The API SHALL provide health check endpoints for monitoring server status and version compatibility.

#### Scenario: Liveness check
- **WHEN** client sends `GET /api/v1/health`
- **THEN** server returns 200 OK
- **AND** response contains `{"status": "ok"}`

#### Scenario: Liveness check with version info
- **WHEN** client sends `GET /api/v1/health`
- **THEN** response includes version object
- **AND** version object contains `api` (server version)
- **AND** version object contains `min_client` (minimum compatible CLI version)

#### Scenario: Readiness check
- **WHEN** client sends `GET /api/v1/health/ready`
- **AND** database is accessible
- **THEN** server returns 200 OK
- **AND** response contains `{"status": "ready", "database": "connected"}`

#### Scenario: Readiness check with database error
- **WHEN** client sends `GET /api/v1/health/ready`
- **AND** database is not accessible
- **THEN** server returns 503 Service Unavailable

## REMOVED Requirements

### Requirement: API Server Command
**Reason**: The API server is no longer a subcommand of the CLI. It is now a standalone binary (`oak-api` or similar).

**Migration**: Users who previously ran `oak serve` should now run the `oak-api` binary directly. All flags are replaced by environment variables for container compatibility.
