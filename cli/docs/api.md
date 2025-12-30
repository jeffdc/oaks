# Oak Compendium API Documentation

The Oak Compendium API provides programmatic access to the Quercus species database.

## Overview

- **Base URL**: `https://oak-compendium-api.fly.dev/api/v1`
- **Protocol**: HTTPS only
- **Format**: All requests and responses use JSON
- **Content-Type**: `application/json`

## Authentication

The API uses Bearer token authentication for write operations.

### Getting an API Key

API keys are generated automatically on first server start:

```bash
# Keys are stored in ~/.oak/api_key
cat ~/.oak/api_key
```

Or set via environment variable:

```bash
export OAK_API_KEY="your-api-key-here"
```

### Using the API Key

Include the API key in the `Authorization` header:

```bash
curl -X POST https://oak-compendium-api.fly.dev/api/v1/species \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scientific_name": "alba", "is_hybrid": false}'
```

### Which Endpoints Require Authentication

| Method | Authentication Required |
|--------|------------------------|
| GET, HEAD, OPTIONS | No (public read access) |
| POST, PUT, DELETE, PATCH | Yes (Bearer token) |

## Rate Limits

Rate limits are applied per IP address:

| Endpoint Type | Limit | Window |
|---------------|-------|--------|
| Read (GET) | 10 requests | 1 second |
| Write (POST/PUT/DELETE) | 5 requests | 1 second |
| Backup endpoints | 1 request | 1 minute |
| Health endpoints | Unlimited | - |

### Rate Limit Response

When rate limited, the API returns:

```json
HTTP/1.1 429 Too Many Requests
Retry-After: 1

{
  "error": "rate limit exceeded"
}
```

The `Retry-After` header indicates how many seconds to wait.

---

## Endpoints

### Health

#### GET /health

Liveness check - returns immediately if the server is running.

**Response:**
```json
{
  "status": "ok"
}
```

#### GET /health/ready

Readiness check - verifies database connectivity.

**Response (healthy):**
```json
{
  "status": "ready",
  "database": "connected"
}
```

**Response (unhealthy):**
```json
HTTP/1.1 503 Service Unavailable

{
  "status": "unavailable",
  "database": "error",
  "error": "database not configured"
}
```

---

### Species

#### GET /api/v1/species

List all species with optional filtering and pagination.

**Query Parameters:**

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `limit` | integer | Number of results (1-500) | 50 |
| `offset` | integer | Offset for pagination | 0 |
| `subgenus` | string | Filter by subgenus (Quercus, Cerris, Cyclobalanopsis) | - |
| `section` | string | Filter by section | - |
| `hybrid` | boolean | Filter by hybrid status (true/false) | - |

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/species?subgenus=Quercus&limit=10"
```

**Response:**
```json
{
  "data": [
    {
      "scientific_name": "alba",
      "author": "L.",
      "is_hybrid": false,
      "conservation_status": "LC",
      "subgenus": "Quercus",
      "section": "Quercus",
      "subsection": null,
      "complex": null,
      "parent1": null,
      "parent2": null,
      "synonyms": []
    }
  ],
  "pagination": {
    "total": 450,
    "limit": 10,
    "offset": 0,
    "hasMore": true
  }
}
```

#### GET /api/v1/species/{name}

Get a single species by scientific name.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Scientific name (without "Quercus" prefix) |

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/species/alba"
```

**Response:**
```json
{
  "scientific_name": "alba",
  "author": "L.",
  "is_hybrid": false,
  "conservation_status": "LC",
  "subgenus": "Quercus",
  "section": "Quercus",
  "subsection": null,
  "complex": null,
  "parent1": null,
  "parent2": null,
  "synonyms": ["alba var. repanda"]
}
```

**Error Response (404):**
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Species 'unknown' not found"
  }
}
```

#### GET /api/v1/species/search

Search species by query string (matches scientific name, synonyms, local names).

**Query Parameters:**

| Parameter | Type | Description | Required |
|-----------|------|-------------|----------|
| `q` | string | Search query | Yes |
| `limit` | integer | Max results (1-500) | No (default: 50) |

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/species/search?q=white+oak"
```

**Response:**
```json
{
  "data": [
    {
      "scientific_name": "alba",
      "author": "L.",
      "is_hybrid": false,
      "subgenus": "Quercus",
      "section": "Quercus"
    }
  ],
  "query": "white oak",
  "count": 1
}
```

#### POST /api/v1/species

Create a new species entry. **Requires authentication.**

**Request Body:**

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `scientific_name` | string | Species name (2-100 chars) | Yes |
| `author` | string | Taxonomic author | No |
| `is_hybrid` | boolean | Is this a hybrid? | Yes |
| `conservation_status` | string | IUCN status code | No |
| `subgenus` | string | Quercus, Cerris, or Cyclobalanopsis | No |
| `section` | string | Section name | No |
| `subsection` | string | Subsection name | No |
| `complex` | string | Complex name | No |
| `parent1` | string | First hybrid parent | No |
| `parent2` | string | Second hybrid parent | No |
| `synonyms` | array | List of synonym names | No |

**Valid Conservation Status Codes:** EX, EW, CR, EN, VU, NT, LC, DD, NE

**Example:**
```bash
curl -X POST "https://oak-compendium-api.fly.dev/api/v1/species" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "scientific_name": "newspecies",
    "author": "Author 2024",
    "is_hybrid": false,
    "subgenus": "Quercus",
    "section": "Quercus"
  }'
```

**Response (201 Created):**
```json
{
  "scientific_name": "newspecies",
  "author": "Author 2024",
  "is_hybrid": false,
  "subgenus": "Quercus",
  "section": "Quercus"
}
```

**Error Response (409 Conflict):**
```json
{
  "error": {
    "code": "CONFLICT",
    "message": "species already exists: alba"
  }
}
```

#### PUT /api/v1/species/{name}

Update an existing species. **Requires authentication.**

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Scientific name of species to update |

**Request Body:** Same as POST, but `scientific_name` is ignored (use path parameter).

**Example:**
```bash
curl -X PUT "https://oak-compendium-api.fly.dev/api/v1/species/alba" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "conservation_status": "NT"
  }'
```

**Response (200 OK):** Updated species object

#### DELETE /api/v1/species/{name}

Delete a species. **Requires authentication.**

**Example:**
```bash
curl -X DELETE "https://oak-compendium-api.fly.dev/api/v1/species/obsolete" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

**Response:** 204 No Content

---

### Taxa

Taxonomic hierarchy (subgenera, sections, subsections, complexes).

#### GET /api/v1/taxa

List all taxa with optional level filter.

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `level` | string | Filter by level: subgenus, section, subsection, complex |

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/taxa?level=section"
```

**Response:**
```json
{
  "data": [
    {
      "name": "Quercus",
      "level": "section",
      "parent": "Quercus",
      "author": "L.",
      "notes": null,
      "links": []
    }
  ],
  "pagination": {
    "total": 25,
    "limit": 25,
    "offset": 0,
    "hasMore": false
  }
}
```

#### GET /api/v1/taxa/{level}/{name}

Get a specific taxon.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `level` | string | Taxon level (subgenus, section, subsection, complex) |
| `name` | string | Taxon name |

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/taxa/section/Quercus"
```

**Response:**
```json
{
  "name": "Quercus",
  "level": "section",
  "parent": "Quercus",
  "author": "L.",
  "notes": "White oaks",
  "links": [
    {
      "title": "Wikipedia",
      "url": "https://en.wikipedia.org/wiki/Quercus_sect._Quercus"
    }
  ]
}
```

#### POST /api/v1/taxa

Create a new taxon. **Requires authentication.**

**Request Body:**

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `name` | string | Taxon name | Yes |
| `level` | string | subgenus, section, subsection, complex | Yes |
| `parent` | string | Parent taxon name | No |
| `author` | string | Taxonomic author | No |
| `notes` | string | Notes about taxon | No |
| `links` | array | Related links (title + url) | No |

**Example:**
```bash
curl -X POST "https://oak-compendium-api.fly.dev/api/v1/taxa" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "NewSection",
    "level": "section",
    "parent": "Quercus"
  }'
```

#### PUT /api/v1/taxa/{level}/{name}

Update a taxon. **Requires authentication.** Name and level cannot be changed.

#### DELETE /api/v1/taxa/{level}/{name}

Delete a taxon. **Requires authentication.**

---

### Sources

Data source references (books, websites, personal observations).

#### GET /api/v1/sources

List all sources.

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/sources"
```

**Response:**
```json
[
  {
    "id": 1,
    "source_type": "website",
    "name": "iNaturalist",
    "description": "Community science platform",
    "author": null,
    "year": null,
    "url": "https://inaturalist.org",
    "isbn": null,
    "doi": null,
    "notes": null,
    "license": "CC BY-NC 4.0",
    "license_url": "https://creativecommons.org/licenses/by-nc/4.0/"
  }
]
```

#### GET /api/v1/sources/{id}

Get a source by ID.

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/sources/1"
```

#### POST /api/v1/sources

Create a new source. **Requires authentication.**

**Request Body:**

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `source_type` | string | Source type (website, book, paper, etc.) | Yes |
| `name` | string | Source name | Yes |
| `description` | string | Description | No |
| `author` | string | Author name | No |
| `year` | integer | Publication year | No |
| `url` | string | Source URL | No |
| `isbn` | string | ISBN for books | No |
| `doi` | string | DOI for papers | No |
| `notes` | string | Additional notes | No |
| `license` | string | License name | No |
| `license_url` | string | License URL | No |

**Example:**
```bash
curl -X POST "https://oak-compendium-api.fly.dev/api/v1/sources" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "book",
    "name": "Oaks of North America",
    "author": "John Smith",
    "year": 2023
  }'
```

#### PUT /api/v1/sources/{id}

Update a source. **Requires authentication.**

#### DELETE /api/v1/sources/{id}

Delete a source. **Requires authentication.**

---

### Species Sources

Descriptive data linked to a species from a specific source.

#### GET /api/v1/species/{name}/sources

List all source data for a species.

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/species/alba/sources"
```

**Response:**
```json
[
  {
    "scientific_name": "alba",
    "source_id": 2,
    "local_names": ["white oak", "eastern white oak"],
    "range": "Eastern North America",
    "growth_habit": "Large deciduous tree to 30m",
    "leaves": "Obovate, 12-22cm, 7-9 rounded lobes",
    "flowers": "Catkins in spring",
    "fruits": "Acorns 15-25mm, cup shallow",
    "bark": "Light gray, scaly",
    "twigs": "Reddish-brown, glabrous",
    "buds": "Ovoid, reddish-brown",
    "hardiness_habitat": "USDA zones 3-9",
    "miscellaneous": "State tree of Illinois",
    "url": "https://oaksoftheworld.fr/quercus-alba",
    "is_preferred": true
  }
]
```

#### GET /api/v1/species/{name}/sources/{sourceId}

Get source data for a specific species-source combination.

**Example:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/species/alba/sources/2"
```

#### POST /api/v1/species/{name}/sources

Add source data for a species. **Requires authentication.**

**Request Body:**

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `source_id` | integer | Source ID | Yes |
| `local_names` | array | Common names | No |
| `range` | string | Geographic range | No |
| `growth_habit` | string | Growth habit description | No |
| `leaves` | string | Leaf description | No |
| `flowers` | string | Flower description | No |
| `fruits` | string | Fruit/acorn description | No |
| `bark` | string | Bark description | No |
| `twigs` | string | Twig description | No |
| `buds` | string | Bud description | No |
| `hardiness_habitat` | string | Hardiness/habitat info | No |
| `miscellaneous` | string | Other notes | No |
| `url` | string | Source-specific URL | No |
| `is_preferred` | boolean | Preferred source for display | No |

**Example:**
```bash
curl -X POST "https://oak-compendium-api.fly.dev/api/v1/species/alba/sources" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "source_id": 3,
    "local_names": ["white oak"],
    "leaves": "Rounded lobes, no bristle tips",
    "is_preferred": false
  }'
```

#### PUT /api/v1/species/{name}/sources/{sourceId}

Update source data. **Requires authentication.**

#### DELETE /api/v1/species/{name}/sources/{sourceId}

Delete source data. **Requires authentication.**

---

### Export

#### GET /api/v1/export

Export the complete database as JSON (same format as web app data file).

**Headers:**

| Header | Description |
|--------|-------------|
| `ETag` | Content hash for caching |
| `Cache-Control` | `public, max-age=300` (5 minutes) |

**Conditional Request:**
```bash
curl "https://oak-compendium-api.fly.dev/api/v1/export" \
  -H "If-None-Match: \"abc123\""
```

Returns `304 Not Modified` if data hasn't changed.

**Response:**
```json
{
  "species": [
    {
      "name": "alba",
      "author": "L.",
      "is_hybrid": false,
      "conservation_status": "LC",
      "taxonomy": {
        "genus": "Quercus",
        "subgenus": "Quercus",
        "section": "Quercus",
        "subsection": null,
        "complex": null
      },
      "parent1": null,
      "parent2": null,
      "hybrids": ["bebbiana"],
      "closely_related_to": ["stellata"],
      "subspecies_varieties": [],
      "synonyms": [],
      "sources": [
        {
          "source_id": 2,
          "source_name": "Oaks of the World",
          "source_url": "https://oaksoftheworld.fr",
          "is_preferred": true,
          "local_names": ["white oak"],
          "range": "Eastern North America",
          "leaves": "...",
          "fruits": "..."
        }
      ]
    }
  ]
}
```

---

## Error Handling

### Error Response Format

All errors return a consistent JSON structure:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "details": { }
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_ERROR` | 400 | Invalid request parameters or body |
| `UNAUTHORIZED` | 401 | Missing or invalid API key |
| `NOT_FOUND` | 404 | Resource does not exist |
| `CONFLICT` | 409 | Resource already exists |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error |

### Validation Error Details

Validation errors include field-level details:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "errors": [
        {"field": "scientific_name", "message": "is required"},
        {"field": "subgenus", "message": "must be one of: Quercus, Cerris, Cyclobalanopsis"}
      ]
    }
  }
}
```

---

## Response Headers

All responses include:

| Header | Description |
|--------|-------------|
| `X-Request-ID` | Unique request identifier for debugging |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Content-Security-Policy` | `default-src 'none'` |
| `Cache-Control` | `no-store` (except /export) |

---

## CORS

The API supports Cross-Origin Resource Sharing for:

- `https://oakcompendium.org`
- `https://oakcompendium.com`
- `http://localhost:*` (development)

**Allowed Methods:** GET, POST, PUT, DELETE, OPTIONS

**Allowed Headers:** Accept, Authorization, Content-Type, X-API-Key, X-Request-ID

---

## Examples

### List All Species in a Section

```bash
curl "https://oak-compendium-api.fly.dev/api/v1/species?section=Quercus&limit=100"
```

### Get Species with Source Data

```bash
# Get the species
curl "https://oak-compendium-api.fly.dev/api/v1/species/alba"

# Get descriptive data from all sources
curl "https://oak-compendium-api.fly.dev/api/v1/species/alba/sources"
```

### Create a Species with Field Notes

```bash
# 1. Create the species entry
curl -X POST "https://oak-compendium-api.fly.dev/api/v1/species" \
  -H "Authorization: Bearer $OAK_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scientific_name": "myspecies", "is_hybrid": false, "subgenus": "Quercus"}'

# 2. Add your personal notes (assuming source_id 3 is "Personal Observation")
curl -X POST "https://oak-compendium-api.fly.dev/api/v1/species/myspecies/sources" \
  -H "Authorization: Bearer $OAK_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "source_id": 3,
    "leaves": "Distinctive waxy cuticle",
    "miscellaneous": "Observed at elevation 1200m",
    "is_preferred": true
  }'
```

### Search for Hybrids

```bash
curl "https://oak-compendium-api.fly.dev/api/v1/species?hybrid=true&limit=50"
```

### Export Data for Offline Use

```bash
# Full export
curl -o quercus_data.json "https://oak-compendium-api.fly.dev/api/v1/export"

# Conditional update (only downloads if changed)
curl -o quercus_data.json "https://oak-compendium-api.fly.dev/api/v1/export" \
  -H "If-None-Match: \"$(md5 -q quercus_data.json 2>/dev/null || echo '')\""
```

---

## Changelog

### v1.0.0 (2025-12-30)

Initial API release:
- Species CRUD operations with filtering and search
- Taxa (taxonomy hierarchy) management
- Sources (data references) management
- Species-Sources (descriptive data) management
- Full database export with ETag caching
- Bearer token authentication for write operations
- Per-IP rate limiting
- CORS support for web applications
