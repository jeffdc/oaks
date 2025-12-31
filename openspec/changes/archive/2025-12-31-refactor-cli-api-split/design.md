# Design: Split CLI and API Server

## Context

The Oak Compendium project currently bundles the CLI tool and API server in a single Go binary (`cli/oak`). The API server was added via `add-crud-api-server` change and is deployed to Fly.io. Now we need to:

1. Allow the CLI to communicate with the deployed API server
2. Reduce deployment size by splitting into separate binaries
3. Maintain shared code without duplication

## Goals / Non-Goals

**Goals:**
- Separate API server from CLI into distinct binaries
- Enable CLI to operate on remote API server
- Reduce API server container size
- Maintain development ergonomics with Go workspace

**Non-Goals:**
- Changing API behavior or endpoints
- Adding new CLI commands
- Supporting multiple simultaneous API connections
- Implementing full offline/sync mode for CLI

## Decisions

### Decision 1: Go Workspace for Shared Code

**Choice:** Use Go 1.18+ workspaces (`go.work`) to manage multiple modules.

**Rationale:**
- Allows `api/` and `cli/` to have separate `go.mod` files
- Shared packages can live in either module and be imported
- Single `go build` command works from any directory
- IDE support (gopls) works seamlessly

**Alternatives considered:**
- **Separate repositories**: Too fragmented for a single-person project
- **Monorepo with single go.mod**: Can't have separate dependencies
- **Copy-paste shared code**: Maintenance nightmare

### Decision 2: Shared Models Location

**Choice:** Keep models in `api/internal/models/` and import from CLI.

**Rationale:**
- API server defines the canonical data structures
- CLI imports types for serialization/deserialization
- Avoids `pkg/` directory for a project of this size

**Alternatives considered:**
- **Separate `pkg/models/` directory**: Adds another module, more complexity
- **Duplicate models in each module**: Drift risk, more maintenance

### Decision 3: CLI Configuration Approach

**Choice:** Environment variables with optional YAML config file fallback.

```bash
# Environment variables (highest priority)
OAK_API_URL=https://api.oakcompendium.com
OAK_API_KEY=secret-key

# Config file fallback (~/.oak/config.yaml)
api:
  url: https://api.oakcompendium.com
  key: secret-key
```

**Rationale:**
- Environment variables work well in CI/CD and containers
- YAML config is user-friendly for local development
- Matches existing pattern (`~/.oak/api_key`)

**Alternatives considered:**
- **Command-line flags only**: Tedious for frequent use
- **JSON config**: YAML is already a dependency and more readable

### Decision 4: Local vs Remote Mode Detection

**Choice:** Auto-detect based on configuration presence, with explicit override flags.

```bash
# Auto-detect: if OAK_API_URL is set, use remote
oak find alba          # Uses API if configured, else local DB

# Explicit override
oak find alba --local  # Force local database
oak find alba --remote # Force API (fails if not configured)
```

**Rationale:**
- Most users will have one primary mode
- Explicit flags for edge cases (testing, debugging)
- Fail-fast if remote requested but not configured

### Decision 5: API Client Design

**Choice:** Simple HTTP client with method-per-endpoint pattern.

```go
type Client struct {
    baseURL string
    apiKey  string
    http    *http.Client
}

func (c *Client) GetSpecies(name string) (*models.Species, error)
func (c *Client) CreateSpecies(s *models.Species) error
func (c *Client) UpdateSpecies(name string, s *models.Species) error
func (c *Client) DeleteSpecies(name string) error
func (c *Client) SearchSpecies(query string) ([]models.Species, error)
// ... etc
```

**Rationale:**
- Simple, explicit, easy to test
- No complex abstraction needed for ~20 endpoints
- Error handling is straightforward

**Alternatives considered:**
- **Generated client from OpenAPI**: Overkill, adds tooling
- **Generic REST client**: Loses type safety

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| API/CLI model drift | Models live in API module; CLI imports them |
| Breaking changes during refactor | Maintain test coverage, staged rollout |
| Workspace complexity | Well-documented setup in README |
| Two binaries to maintain | Single CI pipeline handles both |

## Migration Plan

### Phase 1: Setup (non-breaking)
1. Create `go.work` file
2. Create `api/` directory with empty module
3. Verify workspace works with existing code

### Phase 2: Extract API (breaking for deployment)
1. Move API code to `api/`
2. Update imports
3. Create new Dockerfile
4. Deploy to staging

### Phase 3: CLI Client (non-breaking)
1. Add client package to CLI
2. Integrate with commands
3. Add configuration handling

### Phase 4: Cleanup
1. Remove old `serve` command from CLI
2. Update documentation
3. Archive this change

### Rollback
- Keep old Dockerfile until new deployment verified
- Can revert to single-binary by removing `go.work` and restoring `cli/internal/api/`

### Decision 6: Export Behavior

**Question:** Should `oak export` fetch from API by default when configured?

**Options:**

| Option | Behavior | Pros | Cons |
|--------|----------|------|------|
| A. Always local | `oak export` uses local DB | Fast, no network needed | Remote data requires explicit flag |
| B. Follow mode | Uses API if configured, else local | Consistent with other commands | Slow for large exports, unexpected network |
| C. Explicit only | Require `--local` or `--from-api` | No ambiguity | Tedious for common case |
| D. Profile-based | Depends on active profile (see Decision 7) | Contextual behavior | Adds complexity |

**Recommendation:** Option A (always local) with `--from-api` flag.

**Rationale:**
- Export is often used for backup/versioning local work
- Network export can be slow (~1MB JSON)
- Users expecting local export shouldn't accidentally hit the network
- `oak export --from-api output.json` is clear intent

### Decision 7: Multiple API Profiles

**Requirement:** Support staging vs production to avoid mucking up prod data during testing.

**Choice:** Named profiles in config file with `--profile` flag and `OAK_PROFILE` env var.

```yaml
# ~/.oak/config.yaml
profiles:
  prod:
    url: https://api.oakcompendium.com
    key: prod-api-key-here
  local-server:
    url: http://localhost:8080
    key: dev-key

# default_profile: prod  # Uncomment to default to remote
```

**Usage:**
```bash
# No config or no default_profile → uses local database
oak find alba

# Explicit profile selection
oak find alba --profile prod
oak edit alba --profile local-server

# Environment override (useful in CI/scripts)
OAK_PROFILE=prod oak find alba

# Legacy env vars still work (override everything)
OAK_API_URL=http://localhost:8080 oak find alba
```

**Profile Resolution Order:**
1. `OAK_API_URL` + `OAK_API_KEY` env vars (legacy, overrides all)
2. `--profile` flag
3. `OAK_PROFILE` env var
4. `default_profile` from config file
5. No profile → **local database mode** (safe default for development)

**Safety Features:**
- Default to local database (no accidental remote changes)
- Commands that mutate data remotely show profile name: `Deleting alba from [prod]... confirm? (y/N)`
- `oak config show` displays active profile and URL (or "local" if no remote)
- Must explicitly opt-in to remote operations via `--profile` or config

**Alternatives considered:**
- **Separate config files**: `~/.oak/staging.yaml`, `~/.oak/prod.yaml` — harder to manage
- **URL aliases only**: Less structured, no key management
- **Single profile**: Doesn't meet the staging/prod requirement

### Decision 8: API Version Compatibility

**Question:** How should CLI handle API version mismatches?

**Problem:** If CLI and API server are updated independently, they could become incompatible:
- CLI expects field that API doesn't return
- API returns new required field CLI doesn't handle
- Breaking changes in request/response format

**Choice:** Semantic versioning with compatibility checking.

**API Side:**
```go
// Health endpoint includes version info
GET /api/v1/health
{
  "status": "ok",
  "version": {
    "api": "1.2.0",           // Semantic version
    "min_client": "1.0.0"     // Minimum compatible CLI version
  }
}
```

**CLI Side:**
```go
const CLIVersion = "1.1.0"

func (c *Client) CheckCompatibility() error {
    health, _ := c.Health()

    if semver.Compare(CLIVersion, health.Version.MinClient) < 0 {
        return fmt.Errorf(
            "CLI version %s is too old for API (requires >= %s). Run: go install github.com/jeff/oaks/cli@latest",
            CLIVersion, health.Version.MinClient,
        )
    }
    return nil
}
```

**Behavior:**

| Scenario | Action |
|----------|--------|
| CLI older than `min_client` | Error with upgrade instructions |
| CLI newer than API | Warning (may have reduced functionality) |
| Versions compatible | Silent operation |
| Version check fails | Warning, proceed anyway |

**Version Check Timing:**
- On first API call of session (cached for 5 minutes)
- Can skip with `--skip-version-check` for emergencies
- `oak version` shows both CLI and connected API version

**Version Bump Rules:**
- **Patch (1.0.x)**: Bug fixes, no compatibility impact
- **Minor (1.x.0)**: New features, backward compatible
- **Major (x.0.0)**: Breaking changes, bump `min_client`

**Example Scenarios:**

1. **New optional field added to API response:**
   - API: 1.1.0 → 1.2.0 (minor bump)
   - CLI 1.1.0 works fine (ignores new field)
   - No `min_client` change needed

2. **Required field removed from API response:**
   - API: 1.2.0 → 2.0.0 (major bump)
   - Set `min_client: 2.0.0`
   - Old CLIs get error with upgrade instructions

3. **CLI adds feature using new endpoint:**
   - CLI: 1.2.0 → 1.3.0
   - Works with API 1.3.0+
   - Older API returns 404, CLI shows "Feature requires API >= 1.3.0"

## Open Questions

None — all questions resolved above. Ready for implementation.
