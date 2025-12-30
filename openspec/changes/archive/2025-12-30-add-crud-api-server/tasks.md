<!--
IMPORTANT FOR WORKERS:
This task list has been imported into beads for tracking.
Use `bd show oaks-26qm` to see the master epic and its children.
Use `bd ready` to find tasks with no blockers.
Update task status via `bd update <id> --status=in_progress|closed`.
The markdown checklist below is for reference only - beads is the source of truth.
-->

## 1. Project Setup

- [ ] 1.1 Add chi router dependency to go.mod
- [ ] 1.2 Add httprate (rate limiting) dependency
- [ ] 1.3 Add cors middleware dependency
- [ ] 1.4 Add validation library (go-playground/validator)
- [ ] 1.5 Create `cli/internal/api/` package directory

## 2. Core API Infrastructure

- [ ] 2.1 Create `api/server.go` with Server struct and Start/Stop methods
- [ ] 2.2 Create `api/middleware.go` with logging, recovery, request ID
- [ ] 2.3 Create `api/auth.go` with API key authentication middleware
- [ ] 2.4 Create `api/errors.go` with error response helpers
- [ ] 2.5 Create `api/response.go` with success response helpers
- [ ] 2.6 Add CORS middleware configuration
- [ ] 2.7 Add rate limiting middleware

## 3. Health Endpoints

- [ ] 3.1 Create `api/handlers/health.go`
- [ ] 3.2 Implement `GET /api/v1/health` (basic liveness)
- [ ] 3.3 Implement `GET /api/v1/health/ready` (database connectivity check)

## 4. Species Endpoints (oak_entries)

- [ ] 4.1 Create `api/handlers/species.go`
- [ ] 4.2 Implement `GET /api/v1/species` (list with pagination)
- [ ] 4.3 Implement `GET /api/v1/species/:name` (get by name)
- [ ] 4.4 Implement `POST /api/v1/species` (create)
- [ ] 4.5 Implement `PUT /api/v1/species/:name` (update)
- [ ] 4.6 Implement `DELETE /api/v1/species/:name` (delete)
- [ ] 4.7 Implement `GET /api/v1/species/search?q=...` (search)
- [ ] 4.8 Add input validation for species requests
- [ ] 4.9 Write tests for species handlers

## 5. Taxonomy Endpoints (taxa)

- [ ] 5.1 Create `api/handlers/taxa.go`
- [ ] 5.2 Implement `GET /api/v1/taxa` (list, optional level filter)
- [ ] 5.3 Implement `GET /api/v1/taxa/:level/:name` (get specific)
- [ ] 5.4 Implement `POST /api/v1/taxa` (create)
- [ ] 5.5 Implement `PUT /api/v1/taxa/:level/:name` (update)
- [ ] 5.6 Implement `DELETE /api/v1/taxa/:level/:name` (delete)
- [ ] 5.7 Add input validation for taxa requests
- [ ] 5.8 Write tests for taxa handlers

## 6. Sources Endpoints

- [ ] 6.1 Create `api/handlers/sources.go`
- [ ] 6.2 Implement `GET /api/v1/sources` (list)
- [ ] 6.3 Implement `GET /api/v1/sources/:id` (get by ID)
- [ ] 6.4 Implement `POST /api/v1/sources` (create)
- [ ] 6.5 Implement `PUT /api/v1/sources/:id` (update)
- [ ] 6.6 Implement `DELETE /api/v1/sources/:id` (delete)
- [ ] 6.7 Add input validation for source requests
- [ ] 6.8 Write tests for sources handlers

## 7. Species-Source Endpoints (species_sources)

- [ ] 7.1 Create `api/handlers/species_sources.go`
- [ ] 7.2 Implement `GET /api/v1/species/:name/sources` (list sources for species)
- [ ] 7.3 Implement `GET /api/v1/species/:name/sources/:sourceId` (get specific)
- [ ] 7.4 Implement `POST /api/v1/species/:name/sources` (add source data)
- [ ] 7.5 Implement `PUT /api/v1/species/:name/sources/:sourceId` (update)
- [ ] 7.6 Implement `DELETE /api/v1/species/:name/sources/:sourceId` (delete)
- [ ] 7.7 Add input validation for species-source requests
- [ ] 7.8 Write tests for species-source handlers

## 8. Export Endpoint

- [ ] 8.1 Create `api/handlers/export.go`
- [ ] 8.2 Implement `GET /api/v1/export` (full JSON export, matches web format)
- [ ] 8.3 Add streaming response for large exports
- [ ] 8.4 Write tests for export handler

## 9. Backup System

- [ ] 9.1 Create `api/backup.go` with backup logic
- [ ] 9.2 Evaluate and select S3-compatible storage provider (B2, R2, S3, etc.)
- [ ] 9.3 Add S3 client configuration for selected provider
- [ ] 9.4 Implement `POST /api/v1/backup` endpoint
- [ ] 9.5 Implement scheduled backup goroutine (daily)
- [ ] 9.6 Add backup restore documentation
- [ ] 9.7 Test backup and restore cycle

## 10. CLI Command (oak serve)

- [ ] 10.1 Create `cmd/serve.go` with cobra command
- [ ] 10.2 Add flags: --port, --host, --db-path
- [ ] 10.3 Add API key generation on first run
- [ ] 10.4 Add --regenerate-key flag
- [ ] 10.5 Add graceful shutdown handling
- [ ] 10.6 Register serve command in root.go

## 11. Fly.io Deployment

- [ ] 11.1 Create `cli/Dockerfile`
- [ ] 11.2 Create `fly.toml` configuration
- [ ] 11.3 Create Fly.io app (`fly apps create`)
- [ ] 11.4 Create persistent volume (`fly volumes create`)
- [ ] 11.5 Set API key secret (`fly secrets set`)
- [ ] 11.6 Initial deployment (`fly deploy`)
- [ ] 11.7 Seed database to volume
- [ ] 11.8 Configure S3 backup secrets
- [ ] 11.9 Configure custom domain `api.oakcompendium.com`
- [ ] 11.10 Set up DNS CNAME record pointing to Fly.io
- [ ] 11.11 Verify TLS certificate provisioning

## 12. GitHub Actions Deployment

- [ ] 12.1 Create `.github/workflows/deploy-api.yml`
- [ ] 12.2 Add Fly.io API token to repo secrets
- [ ] 12.3 Configure trigger (push to main, manual)
- [ ] 12.4 Test automated deployment

## 13. Documentation

- [ ] 13.1 Create `cli/docs/api.md` with endpoint documentation
- [ ] 13.2 Add request/response examples for each endpoint
- [ ] 13.3 Document authentication setup
- [ ] 13.4 Document Fly.io deployment process
- [ ] 13.5 Update CLAUDE.md with API architecture
- [ ] 13.6 Update openspec/project.md

## 14. Integration Testing

- [ ] 14.1 Create integration test suite
- [ ] 14.2 Test authentication flows
- [ ] 14.3 Test CRUD operations end-to-end
- [ ] 14.4 Test error handling
- [ ] 14.5 Test rate limiting
- [ ] 14.6 Load testing (basic)

## 15. Security Review

- [ ] 15.1 Verify all endpoints require authentication
- [ ] 15.2 Verify SQL injection prevention
- [ ] 15.3 Verify input validation coverage
- [ ] 15.4 Review CORS configuration
- [ ] 15.5 Check for sensitive data in logs
- [ ] 15.6 Run `govulncheck` on dependencies

## 16. Web App Hybrid Data Loading (Future Phase)

- [ ] 16.1 Create `web/src/lib/apiClient.js` for API communication
- [ ] 16.2 Add API connectivity check on app load
- [ ] 16.3 Modify `dataStore.js` to fetch from API when online
- [ ] 16.4 Update IndexedDB population to use API data
- [ ] 16.5 Keep static JSON as fallback/seed data
- [ ] 16.6 Update service worker to cache API responses
- [ ] 16.7 Add offline indicator in UI
- [ ] 16.8 Test offline/online transitions
- [ ] 16.9 Document hybrid data loading in web/CLAUDE.md
