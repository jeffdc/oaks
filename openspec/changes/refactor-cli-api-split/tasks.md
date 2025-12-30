# Tasks: Split CLI and API Server

## 1. Setup Go Workspace
- [ ] 1.1 Create `go.work` file at repository root
- [ ] 1.2 Create `api/` directory structure
- [ ] 1.3 Initialize `api/go.mod`
- [ ] 1.4 Update `cli/go.mod` to remove API dependencies

## 2. Extract API Server
- [ ] 2.1 Create `api/main.go` with server startup
- [ ] 2.2 Move `cli/internal/api/` to `api/internal/handlers/`
- [ ] 2.3 Move/copy `cli/internal/db/` to `api/internal/db/`
- [ ] 2.4 Move/copy `cli/internal/models/` to shared location
- [ ] 2.5 Create `api/internal/export/` for export functionality
- [ ] 2.6 Update all import paths in moved files
- [ ] 2.7 Add version info to health endpoint response
- [ ] 2.8 Verify API server builds: `cd api && go build`

## 3. CLI Profile Support
- [ ] 3.1 Create `cli/internal/config/` package
- [ ] 3.2 Implement profile config file parsing (`~/.oak/config.yaml`)
- [ ] 3.3 Implement profile resolution (flag → env → config → local)
- [ ] 3.4 Add `--profile` global flag to root command
- [ ] 3.5 Create `oak config show` command
- [ ] 3.6 Create `oak config list` command
- [ ] 3.7 Add profile name to destructive operation prompts (remote only)

## 4. CLI API Client
- [ ] 4.1 Remove `cli/cmd/serve.go`
- [ ] 4.2 Remove `cli/internal/api/` directory
- [ ] 4.3 Create `cli/internal/client/client.go` - base HTTP client
- [ ] 4.4 Implement version compatibility checking
- [ ] 4.5 Create `cli/internal/client/species.go` - species operations
- [ ] 4.6 Create `cli/internal/client/taxa.go` - taxa operations
- [ ] 4.7 Create `cli/internal/client/sources.go` - source operations
- [ ] 4.8 Verify CLI builds: `cd cli && go build`

## 5. Integrate API Client into CLI Commands
- [ ] 5.1 Update `oak find` to support remote queries
- [ ] 5.2 Update `oak new` to support remote creation (with profile confirmation)
- [ ] 5.3 Update `oak edit` to fetch/push via API (with profile confirmation)
- [ ] 5.4 Update `oak delete` to support remote deletion (with profile confirmation)
- [ ] 5.5 Add `--local` / `--remote` flags
- [ ] 5.6 Update `oak export` with `--from-api` flag
- [ ] 5.7 Update `oak version` to show API version when connected
- [ ] 5.8 Add `--skip-version-check` flag

## 6. Update Deployment
- [ ] 6.1 Create `api/Dockerfile` (minimal alpine image)
- [ ] 6.2 Update `fly.toml` to reference `api/Dockerfile`
- [ ] 6.3 Update `.github/workflows/deploy-api.yml` for new structure
- [ ] 6.4 Test local Docker build: `docker build -f api/Dockerfile .`

## 7. Testing
- [ ] 7.1 Ensure all existing API tests pass in new location
- [ ] 7.2 Add CLI client tests with mock server
- [ ] 7.3 Add profile configuration tests
- [ ] 7.4 Add version compatibility tests
- [ ] 7.5 Integration test: CLI → API → Database round-trip

## 8. Documentation
- [ ] 8.1 Update `CLAUDE.md` with new project structure
- [ ] 8.2 Update `cli/README.md` with remote mode and profile docs
- [ ] 8.3 Create `api/README.md` for server documentation
- [ ] 8.4 Update data flow diagram to show CLI↔API relationship
- [ ] 8.5 Add example `~/.oak/config.yaml` to docs

## 9. Cleanup
- [ ] 9.1 Remove old `cli/Dockerfile`
- [ ] 9.2 Verify no dead code remains
- [ ] 9.3 Run `go mod tidy` in both modules
- [ ] 9.4 Final verification of all tests passing
