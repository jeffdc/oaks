# Security Documentation

This document describes the security measures implemented in the Oak Compendium API.

## Authentication

### API Key Authentication

Write operations (POST, PUT, DELETE, PATCH) require Bearer token authentication. Read operations (GET, HEAD, OPTIONS) are public.

**Key Features:**
- **Constant-time comparison**: API keys are validated using `crypto/subtle.ConstantTimeCompare` to prevent timing attacks (`auth.go:75-79`)
- **Cryptographically secure generation**: Keys are generated using `crypto/rand` with 32 bytes of entropy, base64-encoded (`auth.go:84-91`)
- **Secure storage**: Key files are created with 0600 permissions (`auth.go:127`)
- **Environment variable support**: `OAK_API_KEY` environment variable takes precedence over file storage

**Response Behavior:**
- Missing auth: `401 Unauthorized` with message "Missing authorization header"
- Invalid auth: `401 Unauthorized` with message "Invalid API key"
- Response messages are generic to prevent information leakage

### Endpoint Protection

All write endpoints are protected by the `RequireAuth` middleware (`server.go:90-131`):
- `POST /api/v1/species`
- `PUT /api/v1/species/{name}`
- `DELETE /api/v1/species/{name}`
- `POST /api/v1/taxa`
- `PUT /api/v1/taxa/{level}/{name}`
- `DELETE /api/v1/taxa/{level}/{name}`
- `POST /api/v1/sources`
- `PUT /api/v1/sources/{id}`
- `DELETE /api/v1/sources/{id}`
- `POST /api/v1/species/{name}/sources`
- `PUT /api/v1/species/{name}/sources/{sourceId}`
- `DELETE /api/v1/species/{name}/sources/{sourceId}`

## SQL Injection Prevention

All database queries use parameterized statements with `?` placeholders (`db.go`):

```go
// Example - all user input is passed as parameters, never interpolated
db.conn.QueryRow("SELECT * FROM species WHERE name = ?", userInput)
```

**LIKE Pattern Escaping:**
Search queries use the `escapeLike()` helper function that escapes special characters (`%`, `_`, `\`) to prevent wildcard injection attacks (`db.go:14-22`).

## Input Validation

### Species Endpoints (`species.go`)
- `scientific_name`: Required, 2-100 characters
- `subgenus`: Validated against enum (Quercus, Cerris, Cyclobalanopsis)
- `conservation_status`: Validated against IUCN codes (EX, EW, CR, EN, VU, NT, LC, DD, NE)
- Query parameters: `limit` (positive integer, max 500), `offset` (non-negative integer)

### Taxa Endpoints (`taxa.go`)
- `level`: Validated against enum (subgenus, section, subsection, complex)
- `name`: Required

### Sources Endpoints (`sources.go`)
- `source_type`: Required
- `name`: Required
- `id`: Validated as positive integer

### Species-Sources Endpoints (`species_sources.go`)
- `source_id`: Required, positive integer
- Species existence verified before operations
- Source existence verified before linking

### Request Body Size Limit

All POST/PUT/PATCH requests are limited to 1MB body size to prevent memory exhaustion attacks (`middleware.go:246-258`).

## Rate Limiting

Per-IP rate limiting is applied to all endpoints except health checks (`middleware.go:284-369`):

| Endpoint Type | Limit | Window |
|--------------|-------|--------|
| Read (GET) | 10 requests | 1 second |
| Write (POST/PUT/DELETE) | 5 requests | 1 second |
| Backup | 1 request | 1 minute |

**Features:**
- Rate limit responses (429) include `Retry-After` header
- Health endpoints (`/health`, `/health/ready`) are exempt
- Client IP extracted from `X-Forwarded-For` or `X-Real-IP` headers for proxy support

## CORS Configuration

Cross-Origin Resource Sharing is configured to allow only specific origins (`middleware.go:52-60`, `268-288`):

**Production Origins:**
- `https://oakcompendium.org`
- `https://oakcompendium.com`

**Development:**
- `http://localhost:*` (any port) when `AllowLocalhost: true`

**Credentials:** Not allowed (`AllowCredentials: false`)

## Security Headers

All responses include security headers (`middleware.go:260-280`):

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | `nosniff` | Prevent MIME type sniffing |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `Content-Security-Policy` | `default-src 'none'; frame-ancestors 'none'` | Restrict resource loading |
| `X-XSS-Protection` | `1; mode=block` | XSS protection for older browsers |
| `Cache-Control` | `no-store, no-cache, must-revalidate, private` | Prevent caching of sensitive data |
| `X-Request-ID` | `<unique-id>` | Request tracing |

## Error Handling

### Panic Recovery

The server includes panic recovery middleware that:
- Logs the panic with request context (`middleware.go:209-231`)
- Returns a generic 500 error (no stack trace exposed to client)

### Error Response Format

All errors use a consistent JSON format:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

Error codes: `VALIDATION_ERROR`, `UNAUTHORIZED`, `NOT_FOUND`, `CONFLICT`, `RATE_LIMITED`, `INTERNAL_ERROR`

## Logging

### Request Logging

All requests are logged with structured fields (`middleware.go:185-206`):
- `request_id`: Unique request identifier
- `method`: HTTP method
- `path`: Request path
- `status`: Response status code
- `duration_ms`: Request duration
- `client_ip`: Client IP address

### Sensitive Data

**API keys are never logged.** The `maskAPIKey()` function (`cmd/serve.go:148-156`) displays only asterisks when showing key status at startup.

## HTTP Server Configuration

The server is configured with reasonable timeouts (`server.go:140-146`):
- Read timeout: 15 seconds
- Write timeout: 30 seconds
- Idle timeout: 60 seconds
- Request timeout (middleware): 30 seconds

## Dependency Security

### Vulnerability Scanning

Run `govulncheck` to check for known vulnerabilities:

```bash
cd cli
govulncheck ./...
```

As of 2025-12-30: **No vulnerabilities found.**

### Dependencies

The API uses well-maintained, widely-used libraries:
- `github.com/go-chi/chi/v5` - HTTP router
- `github.com/go-chi/cors` - CORS middleware
- `github.com/go-chi/httprate` - Rate limiting
- `github.com/mattn/go-sqlite3` - SQLite driver

## Security Checklist

- [x] All POST/PUT/DELETE require valid API key
- [x] API key comparison is constant-time
- [x] API key not logged anywhere
- [x] 401 response doesn't leak info
- [x] All endpoints validate input
- [x] SQL injection prevented (parameterized queries)
- [x] JSON size limits enforced (1MB)
- [x] All endpoints rate limited
- [x] Rate limits appropriate for use case
- [x] 429 response includes Retry-After
- [x] Only oakcompendium.org/com allowed (CORS)
- [x] localhost allowed only when configured
- [x] X-Content-Type-Options: nosniff
- [x] X-Frame-Options: DENY
- [x] Content-Security-Policy set
- [x] No known vulnerabilities (govulncheck)
- [x] Request IDs for tracing
- [x] Errors logged with context

## Reporting Security Issues

If you discover a security vulnerability, please report it privately to the project maintainer.
