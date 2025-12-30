## ADDED Requirements

### Requirement: API Server Command
The CLI SHALL provide an `oak serve` command that starts an HTTP API server exposing CRUD operations for all database tables.

#### Scenario: Start server with defaults
- **WHEN** user runs `oak serve`
- **THEN** server starts on port 8080
- **AND** server uses database at `./oak_compendium.db`
- **AND** API key is loaded from `~/.oak/api_key` or generated if missing

#### Scenario: Start server with custom port
- **WHEN** user runs `oak serve --port 3000`
- **THEN** server starts on port 3000

#### Scenario: Start server with custom database
- **WHEN** user runs `oak serve --db /path/to/db.sqlite`
- **THEN** server uses the specified database file

#### Scenario: Regenerate API key
- **WHEN** user runs `oak serve --regenerate-key`
- **THEN** a new API key is generated and saved
- **AND** the new key is displayed to the user

### Requirement: API Authentication
The API SHALL require authentication via API key only for write operations (POST, PUT, DELETE).

#### Scenario: Read without authentication
- **WHEN** client sends GET request without Authorization header
- **THEN** request is processed normally
- **AND** data is returned

#### Scenario: Write with valid API key
- **WHEN** client sends POST/PUT/DELETE request with `Authorization: Bearer <valid-key>`
- **THEN** request is processed normally

#### Scenario: Write without API key
- **WHEN** client sends POST/PUT/DELETE request without Authorization header
- **THEN** server returns 401 Unauthorized
- **AND** response body contains error message

#### Scenario: Write with invalid API key
- **WHEN** client sends POST/PUT/DELETE request with invalid API key
- **THEN** server returns 401 Unauthorized
- **AND** response body contains error message

### Requirement: Health Check Endpoints
The API SHALL provide health check endpoints for monitoring server status.

#### Scenario: Liveness check
- **WHEN** client sends `GET /api/v1/health`
- **THEN** server returns 200 OK
- **AND** response contains `{"status": "ok"}`

#### Scenario: Readiness check
- **WHEN** client sends `GET /api/v1/health/ready`
- **AND** database is accessible
- **THEN** server returns 200 OK
- **AND** response contains `{"status": "ready", "database": "connected"}`

#### Scenario: Readiness check with database error
- **WHEN** client sends `GET /api/v1/health/ready`
- **AND** database is not accessible
- **THEN** server returns 503 Service Unavailable

### Requirement: Species CRUD Operations
The API SHALL provide endpoints to create, read, update, and delete species entries.

#### Scenario: List all species
- **WHEN** client sends `GET /api/v1/species`
- **THEN** server returns 200 OK
- **AND** response contains paginated list of species
- **AND** response includes pagination metadata

#### Scenario: List species with pagination
- **WHEN** client sends `GET /api/v1/species?limit=10&offset=20`
- **THEN** server returns at most 10 species starting from offset 20

#### Scenario: Get species by name
- **WHEN** client sends `GET /api/v1/species/alba`
- **AND** species "alba" exists
- **THEN** server returns 200 OK
- **AND** response contains full species data

#### Scenario: Get non-existent species
- **WHEN** client sends `GET /api/v1/species/nonexistent`
- **THEN** server returns 404 Not Found

#### Scenario: Create species
- **WHEN** client sends `POST /api/v1/species` with valid species data
- **THEN** server returns 201 Created
- **AND** response contains created species
- **AND** species is persisted to database

#### Scenario: Create duplicate species
- **WHEN** client sends `POST /api/v1/species` with existing scientific_name
- **THEN** server returns 409 Conflict

#### Scenario: Update species
- **WHEN** client sends `PUT /api/v1/species/alba` with updated data
- **AND** species "alba" exists
- **THEN** server returns 200 OK
- **AND** species is updated in database

#### Scenario: Delete species
- **WHEN** client sends `DELETE /api/v1/species/alba`
- **AND** species "alba" exists
- **THEN** server returns 200 OK
- **AND** species is removed from database
- **AND** all species_sources records for that species are also deleted

#### Scenario: Update non-existent species
- **WHEN** client sends `PUT /api/v1/species/nonexistent` with data
- **THEN** server returns 404 Not Found

#### Scenario: Delete non-existent species
- **WHEN** client sends `DELETE /api/v1/species/nonexistent`
- **THEN** server returns 404 Not Found

#### Scenario: Search species
- **WHEN** client sends `GET /api/v1/species/search?q=white`
- **THEN** server returns species matching the search term
- **AND** search matches scientific name, common names, and synonyms

### Requirement: Taxonomy CRUD Operations
The API SHALL provide endpoints to create, read, update, and delete taxonomy entries.

#### Scenario: List all taxa
- **WHEN** client sends `GET /api/v1/taxa`
- **THEN** server returns all taxa across all levels

#### Scenario: List taxa by level
- **WHEN** client sends `GET /api/v1/taxa?level=section`
- **THEN** server returns only taxa at the section level

#### Scenario: Get specific taxon
- **WHEN** client sends `GET /api/v1/taxa/section/Quercus`
- **AND** taxon exists
- **THEN** server returns 200 OK
- **AND** response contains taxon data

#### Scenario: Create taxon
- **WHEN** client sends `POST /api/v1/taxa` with valid taxon data
- **THEN** server returns 201 Created
- **AND** taxon is persisted to database

#### Scenario: Update taxon
- **WHEN** client sends `PUT /api/v1/taxa/section/Quercus` with updated data
- **THEN** server returns 200 OK
- **AND** taxon is updated in database

#### Scenario: Delete taxon
- **WHEN** client sends `DELETE /api/v1/taxa/section/Quercus`
- **AND** taxon exists
- **THEN** server returns 200 OK
- **AND** taxon is removed from database

#### Scenario: Get non-existent taxon
- **WHEN** client sends `GET /api/v1/taxa/section/nonexistent`
- **THEN** server returns 404 Not Found

#### Scenario: Update non-existent taxon
- **WHEN** client sends `PUT /api/v1/taxa/section/nonexistent` with data
- **THEN** server returns 404 Not Found

#### Scenario: Delete non-existent taxon
- **WHEN** client sends `DELETE /api/v1/taxa/section/nonexistent`
- **THEN** server returns 404 Not Found

### Requirement: Sources CRUD Operations
The API SHALL provide endpoints to create, read, update, and delete source entries.

#### Scenario: List all sources
- **WHEN** client sends `GET /api/v1/sources`
- **THEN** server returns all registered sources

#### Scenario: Get source by ID
- **WHEN** client sends `GET /api/v1/sources/1`
- **AND** source exists
- **THEN** server returns 200 OK
- **AND** response contains source data

#### Scenario: Create source
- **WHEN** client sends `POST /api/v1/sources` with valid source data
- **THEN** server returns 201 Created
- **AND** response contains created source with assigned ID

#### Scenario: Update source
- **WHEN** client sends `PUT /api/v1/sources/1` with updated data
- **THEN** server returns 200 OK
- **AND** source is updated in database

#### Scenario: Delete source
- **WHEN** client sends `DELETE /api/v1/sources/1`
- **AND** source exists
- **THEN** server returns 200 OK
- **AND** source is removed from database

#### Scenario: Get non-existent source
- **WHEN** client sends `GET /api/v1/sources/999`
- **THEN** server returns 404 Not Found

#### Scenario: Update non-existent source
- **WHEN** client sends `PUT /api/v1/sources/999` with data
- **THEN** server returns 404 Not Found

#### Scenario: Delete non-existent source
- **WHEN** client sends `DELETE /api/v1/sources/999`
- **THEN** server returns 404 Not Found

### Requirement: Species-Source CRUD Operations
The API SHALL provide endpoints to manage source-attributed data for species.

#### Scenario: List sources for species
- **WHEN** client sends `GET /api/v1/species/alba/sources`
- **THEN** server returns all source data for species "alba"

#### Scenario: Get specific species-source
- **WHEN** client sends `GET /api/v1/species/alba/sources/1`
- **AND** source data exists for species/source combination
- **THEN** server returns 200 OK
- **AND** response contains source-attributed data

#### Scenario: Add source data for species
- **WHEN** client sends `POST /api/v1/species/alba/sources` with source data
- **THEN** server returns 201 Created
- **AND** source data is linked to species

#### Scenario: Update species-source data
- **WHEN** client sends `PUT /api/v1/species/alba/sources/1` with updated data
- **THEN** server returns 200 OK
- **AND** source data is updated

#### Scenario: Delete species-source data
- **WHEN** client sends `DELETE /api/v1/species/alba/sources/1`
- **THEN** server returns 200 OK
- **AND** source data is removed

#### Scenario: Get non-existent species-source
- **WHEN** client sends `GET /api/v1/species/alba/sources/999`
- **THEN** server returns 404 Not Found

#### Scenario: Update non-existent species-source
- **WHEN** client sends `PUT /api/v1/species/alba/sources/999` with data
- **THEN** server returns 404 Not Found

#### Scenario: Delete non-existent species-source
- **WHEN** client sends `DELETE /api/v1/species/alba/sources/999`
- **THEN** server returns 404 Not Found

#### Scenario: Species-source for non-existent species
- **WHEN** client sends `GET /api/v1/species/nonexistent/sources`
- **THEN** server returns 404 Not Found

### Requirement: Data Export
The API SHALL provide an endpoint to export the full database in JSON format.

#### Scenario: Export all data
- **WHEN** client sends `GET /api/v1/export`
- **THEN** server returns 200 OK
- **AND** response contains complete database in JSON format
- **AND** format matches web app's `quercus_data.json` structure

### Requirement: Database Backup
The API SHALL provide backup functionality for disaster recovery.

#### Scenario: Manual backup trigger
- **WHEN** client sends `POST /api/v1/backup`
- **THEN** server creates database backup
- **AND** uploads backup to configured storage
- **AND** returns backup metadata (filename, size, timestamp)

#### Scenario: Backup rate limiting
- **WHEN** client sends `POST /api/v1/backup` twice within one minute
- **THEN** second request returns 429 Too Many Requests

#### Scenario: Automatic daily backup
- **WHEN** server has been running for 24 hours
- **THEN** server automatically creates and uploads backup
- **AND** logs backup success or failure

### Requirement: Rate Limiting
The API SHALL implement rate limiting on API endpoints to prevent abuse and ensure availability. Health endpoints are exempt to ensure monitoring reliability.

#### Scenario: Normal usage
- **WHEN** client sends requests within rate limits
- **THEN** all requests are processed normally
- **AND** response includes rate limit headers

#### Scenario: Read rate limit exceeded
- **WHEN** client exceeds 10 read requests per second from same IP
- **THEN** server returns 429 Too Many Requests
- **AND** response includes `Retry-After` header

#### Scenario: Write rate limit exceeded
- **WHEN** client exceeds 5 write requests per second from same IP
- **THEN** server returns 429 Too Many Requests
- **AND** response includes `Retry-After` header

#### Scenario: Rate limit headers
- **WHEN** any rate-limited request is processed
- **THEN** response includes `X-RateLimit-Limit` header
- **AND** response includes `X-RateLimit-Remaining` header
- **AND** response includes `X-RateLimit-Reset` header

#### Scenario: Health endpoints exempt from rate limiting
- **WHEN** client sends requests to `/api/v1/health` or `/api/v1/health/ready`
- **THEN** requests are not subject to rate limiting
- **AND** response does not include rate limit headers

### Requirement: CORS Support
The API SHALL support Cross-Origin Resource Sharing for web app access.

#### Scenario: Allowed production origins
- **WHEN** request originates from `https://oakcompendium.org` or `https://oakcompendium.com`
- **THEN** response includes appropriate CORS headers
- **AND** request is processed

#### Scenario: Local development origin
- **WHEN** request originates from `http://localhost:5173`
- **THEN** response includes appropriate CORS headers
- **AND** request is processed

#### Scenario: Preflight request
- **WHEN** browser sends OPTIONS preflight request
- **THEN** server returns 200 OK with CORS headers

### Requirement: Error Response Format
The API SHALL return consistent JSON error responses.

#### Scenario: Validation error
- **WHEN** client sends request with invalid data
- **THEN** server returns 400 Bad Request
- **AND** response body contains structured error with field details

#### Scenario: Not found error
- **WHEN** client requests non-existent resource
- **THEN** server returns 404 Not Found
- **AND** response body contains `{"error": {"code": "NOT_FOUND", "message": "..."}}`

#### Scenario: Server error
- **WHEN** unexpected error occurs during request processing
- **THEN** server returns 500 Internal Server Error
- **AND** response body contains generic error message
- **AND** detailed error is logged server-side

### Requirement: Request Logging
The API SHALL log all requests for debugging and auditing.

#### Scenario: Request logged
- **WHEN** any request is processed
- **THEN** server logs request method, path, status code, and duration
- **AND** log includes request ID for tracing

#### Scenario: Sensitive data not logged
- **WHEN** request contains Authorization header
- **THEN** API key value is not included in logs

### Requirement: Input Validation
The API SHALL validate all input to prevent malformed data and security issues.

#### Scenario: Required field missing
- **WHEN** client sends request missing required field
- **THEN** server returns 400 Bad Request
- **AND** response identifies missing field

#### Scenario: Invalid field format
- **WHEN** client sends field with invalid format (e.g., invalid taxon level)
- **THEN** server returns 400 Bad Request
- **AND** response describes validation failure

#### Scenario: SQL injection attempt
- **WHEN** client sends request with SQL injection payload
- **THEN** server safely handles input via parameterized queries
- **AND** no SQL injection occurs

### Requirement: Fly.io Deployment
The API SHALL be deployable to Fly.io with persistent storage.

#### Scenario: Production deployment
- **WHEN** `fly deploy` is run
- **THEN** API server is built and deployed
- **AND** database persists on Fly.io volume
- **AND** TLS is automatically configured

#### Scenario: Database persistence
- **WHEN** server restarts or redeploys
- **THEN** database data is preserved on volume
- **AND** no data loss occurs

#### Scenario: Environment configuration
- **WHEN** server runs on Fly.io
- **THEN** server reads configuration from environment variables
- **AND** API key is loaded from Fly.io secrets
