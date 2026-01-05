<!--
IMPORTANT FOR WORKERS:
This task list has been imported into beads for tracking.
Use `bd show oaks-26qm` to see the master epic and its children.
Use `bd ready` to find tasks with no blockers.
Update task status via `bd update <id> --status=in_progress|closed`.
The markdown checklist below is for reference only - beads is the source of truth.
-->

## 1. Project Setup

- [x] 1.1 Add chi router dependency to go.mod
- [x] 1.2 Add httprate (rate limiting) dependency
- [x] 1.3 Add cors middleware dependency
- [x] 1.4 Add validation library (go-playground/validator)
- [x] 1.5 Create `cli/internal/api/` package directory

## 2. Core API Infrastructure

- [x] 2.1 Create `api/server.go` with Server struct and Start/Stop methods
- [x] 2.2 Create `api/middleware.go` with logging, recovery, request ID
- [x] 2.3 Create `api/auth.go` with API key authentication middleware
- [x] 2.4 Create `api/errors.go` with error response helpers
- [x] 2.5 Create `api/response.go` with success response helpers
- [x] 2.6 Add CORS middleware configuration
- [x] 2.7 Add rate limiting middleware

## 3. Health Endpoints

- [x] 3.1 Create `api/handlers/health.go`
- [x] 3.2 Implement `GET /api/v1/health` (basic liveness)
- [x] 3.3 Implement `GET /api/v1/health/ready` (database connectivity check)

## 4. Species Endpoints (oak_entries)

- [x] 4.1 Create `api/handlers/species.go`
- [x] 4.2 Implement `GET /api/v1/species` (list with pagination)
- [x] 4.3 Implement `GET /api/v1/species/:name` (get by name)
- [x] 4.4 Implement `POST /api/v1/species` (create)
- [x] 4.5 Implement `PUT /api/v1/species/:name` (update)
- [x] 4.6 Implement `DELETE /api/v1/species/:name` (delete)
- [x] 4.7 Implement `GET /api/v1/species/search?q=...` (search)
- [x] 4.8 Add input validation for species requests
- [x] 4.9 Write tests for species handlers

## 5. Taxonomy Endpoints (taxa)

- [x] 5.1 Create `api/handlers/taxa.go`
- [x] 5.2 Implement `GET /api/v1/taxa` (list, optional level filter)
- [x] 5.3 Implement `GET /api/v1/taxa/:level/:name` (get specific)
- [x] 5.4 Implement `POST /api/v1/taxa` (create)
- [x] 5.5 Implement `PUT /api/v1/taxa/:level/:name` (update)
- [x] 5.6 Implement `DELETE /api/v1/taxa/:level/:name` (delete)
- [x] 5.7 Add input validation for taxa requests
- [x] 5.8 Write tests for taxa handlers

## 6. Sources Endpoints

- [x] 6.1 Create `api/handlers/sources.go`
- [x] 6.2 Implement `GET /api/v1/sources` (list)
- [x] 6.3 Implement `GET /api/v1/sources/:id` (get by ID)
- [x] 6.4 Implement `POST /api/v1/sources` (create)
- [x] 6.5 Implement `PUT /api/v1/sources/:id` (update)
- [x] 6.6 Implement `DELETE /api/v1/sources/:id` (delete)
- [x] 6.7 Add input validation for source requests
- [x] 6.8 Write tests for sources handlers

## 7. Species-Source Endpoints (species_sources)

- [x] 7.1 Create `api/handlers/species_sources.go`
- [x] 7.2 Implement `GET /api/v1/species/:name/sources` (list sources for species)
- [x] 7.3 Implement `GET /api/v1/species/:name/sources/:sourceId` (get specific)
- [x] 7.4 Implement `POST /api/v1/species/:name/sources` (add source data)
- [x] 7.5 Implement `PUT /api/v1/species/:name/sources/:sourceId` (update)
- [x] 7.6 Implement `DELETE /api/v1/species/:name/sources/:sourceId` (delete)
- [x] 7.7 Add input validation for species-source requests
- [x] 7.8 Write tests for species-source handlers

## 8. Export Endpoint

- [x] 8.1 Create `api/handlers/export.go`
- [x] 8.2 Implement `GET /api/v1/export` (full JSON export, matches web format)
- [x] 8.3 Add streaming response for large exports
- [x] 8.4 Write tests for export handler

## 9. Backup System

- [x] 9.1 Create `api/backup.go` with backup logic
- [x] 9.2 Evaluate and select S3-compatible storage provider (B2, R2, S3, etc.)
- [x] 9.3 Add S3 client configuration for selected provider
- [x] 9.4 Implement `POST /api/v1/backup` endpoint
- [x] 9.5 Implement scheduled backup goroutine (daily)
- [x] 9.6 Add backup restore documentation
- [x] 9.7 Test backup and restore cycle

## 10. CLI Command (oak serve)

- [x] 10.1 Create `cmd/serve.go` with cobra command
- [x] 10.2 Add flags: --port, --host, --db-path
- [x] 10.3 Add API key generation on first run
- [x] 10.4 Add --regenerate-key flag
- [x] 10.5 Add graceful shutdown handling
- [x] 10.6 Register serve command in root.go

## 11. Fly.io Deployment

- [x] 11.1 Create `cli/Dockerfile`
- [x] 11.2 Create `fly.toml` configuration
- [x] 11.3 Create Fly.io app (`fly apps create`)
- [x] 11.4 Create persistent volume (`fly volumes create`)
- [x] 11.5 Set API key secret (`fly secrets set`)
- [x] 11.6 Initial deployment (`fly deploy`)
- [x] 11.7 Seed database to volume
- [x] 11.8 Configure S3 backup secrets
- [x] 11.9 Configure custom domain `api.oakcompendium.com`
- [x] 11.10 Set up DNS CNAME record pointing to Fly.io
- [x] 11.11 Verify TLS certificate provisioning

## 12. GitHub Actions Deployment

- [x] 12.1 Create `.github/workflows/deploy-api.yml`
- [x] 12.2 Add Fly.io API token to repo secrets
- [x] 12.3 Configure trigger (push to main, manual)
- [x] 12.4 Test automated deployment

## 13. Documentation

- [x] 13.1 Create `cli/docs/api.md` with endpoint documentation
- [x] 13.2 Add request/response examples for each endpoint
- [x] 13.3 Document authentication setup
- [x] 13.4 Document Fly.io deployment process
- [x] 13.5 Update CLAUDE.md with API architecture
- [x] 13.6 Update openspec/project.md

## 14. Integration Testing

- [x] 14.1 Create integration test suite
- [x] 14.2 Test authentication flows
- [x] 14.3 Test CRUD operations end-to-end
- [x] 14.4 Test error handling
- [x] 14.5 Test rate limiting
- [x] 14.6 Load testing (basic)

## 15. Security Review

- [x] 15.1 Verify all endpoints require authentication
- [x] 15.2 Verify SQL injection prevention
- [x] 15.3 Verify input validation coverage
- [x] 15.4 Review CORS configuration
- [x] 15.5 Check for sensitive data in logs
- [x] 15.6 Run `govulncheck` on dependencies

## 16. Web App Hybrid Data Loading (Future Phase)

- [x] 16.1 Create `web/src/lib/apiClient.js` for API communication
- [x] 16.2 Add API connectivity check on app load
- [x] 16.3 Modify `dataStore.js` to fetch from API when online
- [x] 16.4 Update IndexedDB population to use API data
- [x] 16.5 Keep static JSON as fallback/seed data
- [x] 16.6 Update service worker to cache API responses
- [x] 16.7 Add offline indicator in UI
- [x] 16.8 Test offline/online transitions
- [x] 16.9 Document hybrid data loading in web/CLAUDE.md
