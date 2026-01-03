# api-server Spec Delta

## ADDED Requirements

### Requirement: Full Species Endpoint

The API SHALL provide an endpoint that returns a single species with all its source data embedded.

#### Scenario: Get full species

- **WHEN** client sends `GET /api/v1/species/{name}/full`
- **AND** species exists
- **THEN** server returns 200 OK
- **AND** response contains all species fields in API format (scientific_name, author, is_hybrid, conservation_status, subgenus, section, subsection, complex, parent1, parent2, hybrids, closely_related_to, subspecies_varieties, synonyms, external_links)
- **AND** response contains `sources` array with all species_sources data for this species
- **AND** each source entry includes source metadata (source_name, source_url from sources table)
- **AND** each source entry includes species_sources fields (local_names, range, growth_habit, leaves, flowers, fruits, bark, twigs, buds, hardiness_habitat, miscellaneous, url, is_preferred)

#### Scenario: Get full species not found

- **WHEN** client sends `GET /api/v1/species/{name}/full`
- **AND** species does not exist
- **THEN** server returns 404 Not Found

#### Scenario: Get full species with no sources

- **WHEN** client sends `GET /api/v1/species/{name}/full`
- **AND** species exists but has no species_sources records
- **THEN** server returns 200 OK
- **AND** response contains empty `sources` array

#### Scenario: Full species sources ordered by preference

- **WHEN** client sends `GET /api/v1/species/{name}/full`
- **AND** species has multiple sources
- **THEN** `sources` array is ordered with is_preferred=true sources first
- **AND** then ordered by source_id ascending

### Requirement: Gzip Compression

The API SHALL compress JSON responses.

#### Scenario: Large response is compressed

- **WHEN** client sends request with `Accept-Encoding: gzip`
- **AND** response body is larger than threshold (e.g., 1KB)
- **THEN** response includes `Content-Encoding: gzip`
- **AND** response body is gzip compressed

#### Scenario: Small response is not compressed

- **WHEN** client sends request with `Accept-Encoding: gzip`
- **AND** response body is smaller than threshold
- **THEN** response is not compressed (overhead not worth it)

### Requirement: Delete Cascade Protection for Species

The API SHALL prevent deletion of species that are referenced as hybrid parents.

#### Scenario: Delete species with no dependents

- **WHEN** client sends `DELETE /api/v1/species/{name}`
- **AND** species exists
- **AND** no other species reference this as parent1 or parent2
- **THEN** server returns 204 No Content
- **AND** species is deleted

#### Scenario: Delete species referenced as hybrid parent

- **WHEN** client sends `DELETE /api/v1/species/{name}`
- **AND** species exists
- **AND** one or more hybrids reference this species as parent1 or parent2
- **THEN** server returns 409 Conflict
- **AND** response includes error with code "CONFLICT"
- **AND** response includes message indicating how many hybrids reference this species
- **AND** response includes `details.blocking_hybrids` array with names of blocking hybrids

#### Scenario: Delete cascade protection error format

- **WHEN** delete is blocked by hybrid references
- **THEN** response body format is:
```json
{
  "error": {
    "code": "CONFLICT",
    "message": "Cannot delete: N hybrids reference this species as a parent",
    "details": {
      "blocking_hybrids": ["× hybrid1", "× hybrid2", ...]
    }
  }
}
```

## REMOVED Requirements

### Requirement: Data Export

The `/api/v1/export` endpoint SHALL be removed.

- **Migration**: Web app updated to use individual endpoints before removal
- **Breaking change**: Yes, but only web app used this endpoint
- **CLI impact**: None; CLI uses its own `oak export` command, not the API
