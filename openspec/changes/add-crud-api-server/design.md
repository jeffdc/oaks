## Context

The Oak Compendium CLI (`oak`) already has a complete database layer with CRUD operations for all tables. This change wraps that layer in an HTTP API, deployed to Fly.io with proper security and operational concerns.

### Stakeholders
- Primary user (Jeff): API consumer via iOS app and potentially web app
- CLI tool: Continues to work directly against local database
- Future: Third-party consumers if API is made public

### Constraints
- Single-user system initially (no multi-tenancy)
- SQLite database must be persisted (Fly.io volume)
- Database file is small (~5MB) and can be backed up easily
- Must work with iOS app (cellular, high latency tolerance)
- Web app may migrate from static JSON to live API (CORS required)

## Goals / Non-Goals

### Goals
- CRUD API for all database tables
- Secure authentication via API keys
- Fly.io deployment with persistent storage
- Automated backups to external storage
- Request logging and basic monitoring
- Sub-second response times for typical queries

### Non-Goals
- Multi-user support (single API key)
- OAuth/OIDC/social login
- WebSocket real-time updates
- Rate limiting beyond basic abuse prevention
- Full-text search engine (SQLite LIKE is sufficient)
- Geographic queries (future enhancement)

## Decisions

### Decision 1: HTTP Framework - Chi Router

**What**: Use `go-chi/chi` for HTTP routing.

**Why**:
- Lightweight, idiomatic Go (net/http compatible)
- Built-in middleware support (logging, recovery, timeout)
- Simple and well-maintained
- No framework lock-in (handlers are standard http.HandlerFunc)

**Alternatives considered**:
- Gin: More features but heavier, overkill for our needs
- Standard library only: Possible but chi's routing and middleware are worth it
- Echo: Similar to chi, less idiomatic

**Dependencies**:
```go
require github.com/go-chi/chi/v5 v5.0.11
```

### Decision 2: API Versioning - URL Path

**What**: Version API via URL path (`/api/v1/...`).

**Why**:
- Simple and explicit
- Easy to run multiple versions simultaneously
- Clear documentation
- Works with any HTTP client

**Format**: `/api/v1/resource`

**Future**: When breaking changes needed, add `/api/v2/` alongside v1.

### Decision 3: Authentication - API Key for Writes Only

**What**: API key authentication via `Authorization: Bearer <key>` header, required only for write operations.

**Implementation**:
1. Server generates random 32-byte key on first run
2. Key stored in `~/.oak/api_key` (or environment variable `OAK_API_KEY`)
3. Middleware validates key only on POST, PUT, DELETE endpoints
4. Key can be regenerated via `oak serve --regenerate-key`

**Why**:
- Read operations are harmless - no need to protect public species data
- Simplifies client implementation for read-only use cases
- iOS app only needs API key for note submission
- Web app can fetch data without any configuration
- Write protection prevents unauthorized data modification

**Public endpoints** (no auth required):
- All `GET` requests (species, taxa, sources, export, health)

**Protected endpoints** (API key required):
- All `POST` requests (create)
- All `PUT` requests (update)
- All `DELETE` requests (delete)
- `POST /api/v1/backup` (admin operation)

### Decision 4: Deployment - Fly.io

**What**: Deploy as a Fly.io app with persistent volume.

**Why**:
- Simple deployment (`fly deploy`)
- Free tier covers our needs
- Persistent volumes for SQLite
- Automatic TLS certificates
- Easy secrets management
- Good uptime SLA

**Architecture**:
```
┌─────────────────────────────────────────┐
│              Fly.io Edge                │
│         (TLS termination, CDN)          │
└─────────────────┬───────────────────────┘
                  │ HTTPS
                  ▼
┌─────────────────────────────────────────┐
│           Fly Machine (1 instance)       │
│  ┌─────────────────────────────────────┐│
│  │        oak serve (Go binary)        ││
│  │   ┌─────────┐   ┌────────────────┐  ││
│  │   │ chi     │   │ internal/db    │  ││
│  │   │ router  │───│ (existing)     │  ││
│  │   └─────────┘   └───────┬────────┘  ││
│  └─────────────────────────┼───────────┘│
│                            ▼            │
│  ┌─────────────────────────────────────┐│
│  │   Fly Volume (/data)                ││
│  │   └── oak_compendium.db             ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

**fly.toml**:
```toml
app = "oak-compendium-api"
primary_region = "sjc"  # San Jose (close to CA)

[build]
  dockerfile = "cli/Dockerfile"

[env]
  OAK_DB_PATH = "/data/oak_compendium.db"
  OAK_ENV = "production"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false  # Keep running for quick responses
  auto_start_machines = true
  min_machines_running = 1

[[mounts]]
  source = "oak_data"
  destination = "/data"

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256
```

### Decision 5: Database Backups

**What**: Automated backups to cloud storage (S3-compatible).

**Strategy**:
1. **Scheduled backup**: Daily SQLite `.backup` to S3
2. **Manual backup**: `POST /api/v1/backup` triggers immediate backup
3. **Retention**: Keep 30 daily backups, 12 monthly

**Implementation options**:
- **Option A**: Fly.io scheduled machine runs backup script
- **Option B**: GitHub Actions scheduled workflow SSH to Fly machine
- **Option C**: In-process goroutine (simplest)

**Recommended**: Option C - in-process goroutine
- Runs `sqlite3 .backup` daily at 3 AM UTC
- Uploads to S3-compatible storage (TODO: evaluate Backblaze B2, Cloudflare R2, AWS S3, or other options)
- Logs success/failure to stderr
- Manual trigger via API endpoint

**Backup endpoint**: `POST /api/v1/backup`
- Requires admin authentication (same API key)
- Returns backup filename and size
- Rate limited to 1 per minute

### Decision 6: CORS Configuration

**What**: Allow cross-origin requests from web app.

**Allowed origins**:
- `https://oakcompendium.org` (production web app)
- `https://oakcompendium.com` (production web app)
- `http://localhost:*` (local development, any port)

**Configuration**:
```go
cors.Handler(cors.Options{
    AllowedOrigins:   []string{"https://oakcompendium.org", "https://oakcompendium.com"},
    AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
    AllowedHeaders:   []string{"Authorization", "Content-Type"},
    AllowCredentials: true,
    MaxAge:           86400,
    // Use AllowOriginFunc for localhost (chi/cors doesn't support port wildcards)
    AllowOriginFunc: func(r *http.Request, origin string) bool {
        return strings.HasPrefix(origin, "http://localhost:")
    },
})
```

**Note**: chi/cors wildcards like `http://localhost:*` don't work. Use `AllowOriginFunc` for dynamic localhost matching.

### Decision 7: Rate Limiting

**What**: Rate limiting on ALL endpoints to prevent abuse and ensure availability.

**Limits**:
- Global: 100 requests/second (server-wide)
- Per-IP: 10 requests/second for read operations
- Per-IP: 5 requests/second for write operations
- Backup endpoint: 1 request/minute
- Health endpoints: **EXEMPT** (monitoring needs reliable access)

**Implementation**: `go-chi/httprate` middleware applied to API routes (except health)

**Why rate limiting is critical**:
- Read APIs are public - must prevent scraping/DDoS
- Protects SQLite from concurrent query overload
- Ensures iOS app gets responsive service
- Backup endpoint needs strict throttling (expensive operation)

**Rate limit headers** (returned on all responses):
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Requests remaining in window
- `X-RateLimit-Reset`: Unix timestamp when limit resets

### Decision 8: Error Response Format

**What**: Consistent JSON error responses.

**Format**:
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Species 'nonexistent' not found",
    "details": null
  }
}
```

**HTTP Status Codes**:
- 200: Success
- 201: Created
- 400: Bad Request (validation error)
- 401: Unauthorized (missing/invalid API key)
- 404: Not Found
- 409: Conflict (duplicate key)
- 429: Too Many Requests (rate limited)
- 500: Internal Server Error

### Decision 9: Request/Response Formats

**What**: JSON for all request and response bodies.

**Content-Type**: `application/json`

**Pagination** (for list endpoints):
```json
{
  "data": [...],
  "pagination": {
    "total": 672,
    "limit": 50,
    "offset": 0,
    "hasMore": true
  }
}
```

**Query parameters for lists**:
- `limit`: Max items (default 50, max 500)
- `offset`: Skip items (default 0)
- `sort`: Field to sort by
- `order`: `asc` or `desc`

### Decision 10: Input Validation

**What**: Validate all input at the API layer.

**Strategy**:
- Use struct tags for basic validation
- Custom validators for business rules
- Return 400 with specific field errors

**Example**:
```go
type CreateSpeciesRequest struct {
    ScientificName string `json:"scientific_name" validate:"required,min=2,max=100"`
    IsHybrid       bool   `json:"is_hybrid"`
    Subgenus       string `json:"subgenus" validate:"omitempty,oneof=Quercus Cerris Cyclobalanopsis"`
}
```

**SQL Injection**: Prevented by parameterized queries (already implemented in db.go)

### Decision 11: Logging and Monitoring

**What**: Structured logging with request tracing.

**Implementation**:
- `log/slog` for structured JSON logging (Go 1.21+)
- Request ID middleware (chi middleware)
- Log: method, path, status, duration, client IP

**Log format**:
```json
{
  "time": "2025-01-15T10:30:00Z",
  "level": "INFO",
  "msg": "request completed",
  "request_id": "abc123",
  "method": "GET",
  "path": "/api/v1/species/alba",
  "status": 200,
  "duration_ms": 12,
  "client_ip": "1.2.3.4"
}
```

**Monitoring**: Fly.io metrics dashboard + logs

### Decision 12: Database Initialization

**What**: Handle missing/empty database on first run.

**Strategy**:
1. If database file doesn't exist, create it with schema
2. If database exists, verify schema version
3. Run migrations if needed

**Fly.io deployment**:
- First deploy: Copy `cli/oak_compendium.db` to volume
- Subsequent deploys: Database persists on volume

**Initial data seeding**:
```bash
# One-time: Copy database to Fly volume
fly ssh console -C "cat > /data/oak_compendium.db" < cli/oak_compendium.db
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| SQLite not ideal for concurrent writes | Single user, writes are rare (mostly reads) |
| Fly.io outage | Backups allow recovery, local CLI still works |
| API key leaked | Can regenerate, single user limits blast radius |
| Database corruption | Daily backups, SQLite WAL mode for durability |
| Volume data loss | Backups to S3, can restore from git-tracked copy |

## Migration Plan

1. **Phase 1: Local development**
   - Implement API server with all endpoints
   - Test against local database
   - Document all endpoints

2. **Phase 2: Fly.io setup**
   - Create Fly.io app
   - Configure volume
   - Deploy initial version
   - Seed database

3. **Phase 3: Backup automation**
   - Set up S3 bucket
   - Implement backup goroutine
   - Verify backup/restore

4. **Phase 4: iOS integration** (separate change)
   - iOS app uses API for data access
   - Replace Bear sync workflow

5. **Phase 5: Web app evaluation** (future)
   - Assess migrating from static JSON to live API
   - May keep static JSON for offline PWA

**Rollback**: CLI continues to work with local database. API server is purely additive.

### Decision 13: Custom Domain

**What**: Use custom domain `api.oakcompendium.com` for the API.

**Why**:
- Professional appearance
- Easier to remember
- Decoupled from hosting provider (can migrate without URL change)

**Implementation**:
- Register domain or add subdomain to existing oakcompendium.com/org
- Configure DNS CNAME to Fly.io app
- Fly.io handles TLS certificate automatically

### Decision 14: Web App Data Strategy - Hybrid Approach

**What**: Web app fetches from API when online, falls back to cached data for offline.

**Strategy**:
1. On load, check if API is reachable
2. If online: fetch fresh data from API, update IndexedDB cache
3. If offline: serve from IndexedDB (populated from previous API fetch or bundled JSON)
4. Service worker handles caching and offline fallback

**Why**:
- Best of both worlds: fresh data when connected, works offline
- PWA remains functional without network
- Gradual migration from static JSON

**Implementation**:
- Add API client to web app
- Modify data loading to try API first
- Keep JSON as initial seed / fallback
- Service worker caches API responses

## Open Questions

1. **Backup storage provider?** Need to evaluate: Backblaze B2, Cloudflare R2, AWS S3, or alternatives. Consider cost, ease of setup, and S3 compatibility. This decision should be made before implementing the backup system (task 9.2).
