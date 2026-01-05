# Tasks: Split CLI and API Server

## 1. Setup Go Workspace
- [x] 1.1 Create `go.work` file at repository root
- [x] 1.2 Create `api/` directory structure
- [x] 1.3 Initialize `api/go.mod`
- [x] 1.4 Update `cli/go.mod` to remove API dependencies

## 2. Extract API Server
- [x] 2.1 Create `api/main.go` with server startup
- [x] 2.2 Move `cli/internal/api/` to `api/internal/handlers/`
- [x] 2.3 Move/copy `cli/internal/db/` to `api/internal/db/`
- [x] 2.4 Move/copy `cli/internal/models/` to shared location
- [x] 2.5 Create `api/internal/export/` for export functionality
- [x] 2.6 Update all import paths in moved files
- [x] 2.7 Add version info to health endpoint response
- [x] 2.8 Verify API server builds: `cd api && go build`
- [x] 2.9 Create `api/Makefile` (build, lint, test, clean, docker-build)

## 3. CLI Profile Support
- [x] 3.1 Create `cli/internal/config/` package
- [x] 3.2 Implement profile config file parsing (`~/.oak/config.yaml`)
- [x] 3.3 Implement profile resolution (flag → env → config → local)
- [x] 3.4 Add `--profile` global flag to root command
- [x] 3.5 Create `oak config show` command
- [x] 3.6 Create `oak config list` command
- [x] 3.7 Add profile name to destructive operation prompts (remote only)

## 4. CLI API Client
- [x] 4.1 Remove `cli/cmd/serve.go`
- [x] 4.2 Remove `cli/internal/api/` directory
- [x] 4.3 Create `cli/internal/client/client.go` - base HTTP client
- [x] 4.4 Implement version compatibility checking
- [x] 4.5 Create `cli/internal/client/species.go` - species operations
- [x] 4.6 Create `cli/internal/client/taxa.go` - taxa operations
- [x] 4.7 Create `cli/internal/client/sources.go` - source operations
- [x] 4.8 Verify CLI builds: `cd cli && go build`

## 5. Integrate API Client into CLI Commands
- [x] 5.1 Update `oak find` to support remote queries
- [x] 5.2 Update `oak new` to support remote creation (with profile confirmation)
- [x] 5.3 Update `oak edit` to fetch/push via API (with profile confirmation)
- [x] 5.4 Update `oak delete` to support remote deletion (with profile confirmation)
- [x] 5.5 Add `--local` / `--remote` flags
- [x] 5.6 Update `oak export` with `--from-api` flag
- [x] 5.7 Update `oak version` to show API version when connected
- [x] 5.8 Add `--skip-version-check` flag

## 6. Update Deployment
- [x] 6.1 Create `api/Dockerfile` (minimal alpine image)
- [x] 6.2 Update `fly.toml` to reference `api/Dockerfile`
- [x] 6.3 Update `.github/workflows/deploy-api.yml` for new structure
- [x] 6.4 Test local Docker build: `docker build -f api/Dockerfile .`

## 7. Testing
- [x] 7.1 Ensure all existing API tests pass in new location
- [x] 7.2 Add CLI client tests with mock server
- [x] 7.3 Add profile configuration tests
- [x] 7.4 Add version compatibility tests
- [x] 7.5 Integration test: CLI → API → Database round-trip

## 8. Documentation
- [x] 8.1 Update `CLAUDE.md` with new project structure
- [x] 8.2 Update `cli/README.md` with remote mode and profile docs
- [x] 8.3 Create `api/README.md` for server documentation
- [x] 8.4 Update data flow diagram to show CLI↔API relationship
- [x] 8.5 Add example `~/.oak/config.yaml` to docs
- [x] 8.6 Update `CLAUDE.md` CLI/API workflow sections with new build instructions

## 9. Cleanup
- [x] 9.1 Remove old `cli/Dockerfile`
- [x] 9.2 Verify no dead code remains
- [x] 9.3 Run `go mod tidy` in both modules
- [x] 9.4 Final verification of all tests passing
