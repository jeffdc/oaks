## MODIFIED Requirements

### Requirement: Species Management
The API SHALL provide endpoints for creating, reading, updating, and deleting oak species entries. All write operations SHALL maintain bidirectional parent-child relationships for hybrid species.

#### Scenario: Create hybrid species
- **WHEN** a POST request creates a hybrid with parent1="alba" and parent2="macrocarpa"
- **THEN** the hybrid is created successfully
- **AND** the "alba" species' `hybrids` list is updated to include the new hybrid
- **AND** the "macrocarpa" species' `hybrids` list is updated to include the new hybrid

#### Scenario: Update hybrid parents
- **WHEN** a PUT request changes a hybrid's parent1 from "alba" to "robur"
- **THEN** the hybrid is updated successfully
- **AND** the "alba" species' `hybrids` list no longer includes the hybrid
- **AND** the "robur" species' `hybrids` list is updated to include the hybrid

#### Scenario: Delete hybrid species
- **WHEN** a DELETE request removes a hybrid with parent1="alba"
- **THEN** the hybrid is deleted successfully
- **AND** the "alba" species' `hybrids` list no longer includes the deleted hybrid

## ADDED Requirements

### Requirement: Bulk Import Endpoints
The API SHALL provide bulk import endpoints for efficient large-scale data operations.

#### Scenario: Bulk species import
- **WHEN** a POST request to `/api/v1/species/bulk` includes an array of species entries
- **THEN** all entries are created/updated in a single transaction
- **AND** bidirectional relationships are maintained for all hybrids
- **AND** the response includes count of created, updated, and failed entries

#### Scenario: Bulk taxa import
- **WHEN** a POST request to `/api/v1/taxa/bulk` includes an array of taxa entries
- **THEN** all entries are created/updated in a single transaction
- **AND** the response includes count of created, updated, and failed entries

#### Scenario: Bulk import failure handling
- **WHEN** a bulk import encounters an error on one entry
- **THEN** the entire transaction is rolled back
- **AND** the response includes the specific error and entry that failed
- **AND** no partial data is committed

### Requirement: Transaction Support for Write Operations
All write operations that modify multiple related records SHALL use database transactions to ensure consistency.

#### Scenario: Hybrid creation atomicity
- **WHEN** creating a hybrid fails after updating parent1's hybrids list
- **THEN** the transaction is rolled back
- **AND** parent1's hybrids list remains unchanged
- **AND** no partial data is committed

#### Scenario: Concurrent write handling
- **WHEN** multiple concurrent requests attempt to modify the same species
- **THEN** SQLite's transaction isolation prevents data corruption
- **AND** one request succeeds while others may retry
