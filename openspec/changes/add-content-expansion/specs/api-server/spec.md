# api-server Specification Delta

## ADDED Requirements

### Requirement: Species Backlinks Endpoint

The API SHALL provide an endpoint to retrieve content that links to a species.

#### Scenario: Get backlinks for species
- **WHEN** client sends `GET /api/v1/species/:name/backlinks`
- **AND** taxa or articles contain links to that species
- **THEN** server returns list of backlinks with type and metadata

#### Scenario: Get backlinks for species with no references
- **WHEN** client sends `GET /api/v1/species/:name/backlinks`
- **AND** no content links to that species
- **THEN** server returns empty array

#### Scenario: Get backlinks for non-existent species
- **WHEN** client sends `GET /api/v1/species/nonexistent/backlinks`
- **THEN** server returns empty array (not 404)

### Requirement: Article CRUD Operations

The API SHALL provide endpoints to create, read, update, and delete articles.

#### Scenario: List all published articles
- **WHEN** client sends `GET /api/v1/articles`
- **THEN** server returns all articles where `is_published` is true
- **AND** articles are sorted by `published_at` descending
- **AND** response includes pagination metadata

#### Scenario: List articles with pagination
- **WHEN** client sends `GET /api/v1/articles?limit=10&offset=20`
- **THEN** server returns at most 10 articles starting from offset 20

#### Scenario: List articles filtered by tag
- **WHEN** client sends `GET /api/v1/articles?tag=guides`
- **THEN** server returns only articles with "guides" in tags array

#### Scenario: Get article by slug
- **WHEN** client sends `GET /api/v1/articles/:slug`
- **AND** article exists and is published
- **THEN** server returns 200 OK with article data

#### Scenario: Get unpublished article without auth
- **WHEN** client sends `GET /api/v1/articles/:slug`
- **AND** article exists but `is_published` is false
- **AND** request has no valid Authorization header
- **THEN** server returns 404 Not Found

#### Scenario: Get unpublished article with auth
- **WHEN** client sends `GET /api/v1/articles/:slug`
- **AND** article exists but `is_published` is false
- **AND** request has valid Authorization header
- **THEN** server returns 200 OK with article data

#### Scenario: Create article
- **WHEN** client sends `POST /api/v1/articles` with valid article data
- **AND** request has valid Authorization header
- **THEN** server returns 201 Created
- **AND** response contains created article with generated slug

#### Scenario: Create article without auth
- **WHEN** client sends `POST /api/v1/articles`
- **AND** request has no Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Update article
- **WHEN** client sends `PUT /api/v1/articles/:slug` with updated data
- **AND** article exists
- **AND** request has valid Authorization header
- **THEN** server returns 200 OK
- **AND** `updated_at` is set to current timestamp

#### Scenario: Update article without auth
- **WHEN** client sends `PUT /api/v1/articles/:slug`
- **AND** request has no Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Delete article
- **WHEN** client sends `DELETE /api/v1/articles/:slug`
- **AND** article exists
- **AND** request has valid Authorization header
- **THEN** server returns 200 OK
- **AND** article is removed from database

#### Scenario: Delete article without auth
- **WHEN** client sends `DELETE /api/v1/articles/:slug`
- **AND** request has no Authorization header
- **THEN** server returns 401 Unauthorized

#### Scenario: Get non-existent article
- **WHEN** client sends `GET /api/v1/articles/nonexistent`
- **THEN** server returns 404 Not Found

#### Scenario: Update non-existent article
- **WHEN** client sends `PUT /api/v1/articles/nonexistent` with data
- **AND** request has valid Authorization header
- **THEN** server returns 404 Not Found

#### Scenario: Delete non-existent article
- **WHEN** client sends `DELETE /api/v1/articles/nonexistent`
- **AND** request has valid Authorization header
- **THEN** server returns 404 Not Found

### Requirement: Article Tags Endpoint

The API SHALL provide an endpoint to list all unique article tags.

#### Scenario: List available tags
- **WHEN** client sends `GET /api/v1/articles/tags`
- **THEN** server returns array of all unique tags used across published articles

#### Scenario: List tags with no articles
- **WHEN** client sends `GET /api/v1/articles/tags`
- **AND** no published articles exist
- **THEN** server returns empty array

## MODIFIED Requirements

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

#### Scenario: Article endpoints subject to rate limiting
- **WHEN** client sends requests to `/api/v1/articles` or `/api/v1/articles/:slug`
- **THEN** requests are subject to standard rate limiting
- **AND** response includes rate limit headers

### Requirement: Data Export

The API SHALL provide an endpoint to export the full database in JSON format.

#### Scenario: Export all data
- **WHEN** client sends `GET /api/v1/export`
- **THEN** server returns 200 OK
- **AND** response contains complete database in JSON format
- **AND** format matches web app's `quercus_data.json` structure

#### Scenario: Export includes taxa content
- **WHEN** client sends `GET /api/v1/export`
- **THEN** response includes `taxa` array
- **AND** each taxon includes `content` and `content_updated_at` fields

#### Scenario: Export includes published articles
- **WHEN** client sends `GET /api/v1/export`
- **THEN** response includes `articles` array
- **AND** only articles where `is_published` is true are included
- **AND** each article includes all metadata fields
