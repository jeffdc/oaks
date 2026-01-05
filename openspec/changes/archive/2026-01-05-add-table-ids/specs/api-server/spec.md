## ADDED Requirements

### Requirement: Species ID-Based Lookup

The API SHALL provide an endpoint to retrieve species by integer ID.

#### Scenario: Get species by ID
- **WHEN** client sends `GET /api/v1/species/id/{id}`
- **AND** species with that ID exists
- **THEN** server returns 200 OK
- **AND** response contains full species data including `id` field

#### Scenario: Get species by non-existent ID
- **WHEN** client sends `GET /api/v1/species/id/99999`
- **AND** no species has that ID
- **THEN** server returns 404 Not Found

#### Scenario: Get species by invalid ID format
- **WHEN** client sends `GET /api/v1/species/id/abc`
- **THEN** server returns 400 Bad Request

### Requirement: Taxa ID-Based Lookup

The API SHALL provide an endpoint to retrieve taxa by integer ID.

#### Scenario: Get taxon by ID
- **WHEN** client sends `GET /api/v1/taxa/id/{id}`
- **AND** taxon with that ID exists
- **THEN** server returns 200 OK
- **AND** response contains full taxon data including `id` field

#### Scenario: Get taxon by non-existent ID
- **WHEN** client sends `GET /api/v1/taxa/id/99999`
- **AND** no taxon has that ID
- **THEN** server returns 404 Not Found

#### Scenario: Get taxon by invalid ID format
- **WHEN** client sends `GET /api/v1/taxa/id/abc`
- **THEN** server returns 400 Bad Request

### Requirement: ID Field in API Responses

The API SHALL include integer ID fields in species and taxa responses.

#### Scenario: Species response includes ID
- **WHEN** client requests any species endpoint
- **THEN** response JSON includes `id` field with integer value

#### Scenario: Taxa response includes ID
- **WHEN** client requests any taxa endpoint
- **THEN** response JSON includes `id` field with integer value

#### Scenario: Species list includes IDs
- **WHEN** client sends `GET /api/v1/species`
- **THEN** each species in the response includes its `id` field

#### Scenario: Taxa list includes IDs
- **WHEN** client sends `GET /api/v1/taxa`
- **THEN** each taxon in the response includes its `id` field
