# Tasks: Add Integer IDs to Tables

## 1. Database Schema Migration

- [x] 1.1 Implement pre-flight check for orphaned `species_sources` rows (fail if scientific_name not in oak_entries)
- [x] 1.2 Wrap entire migration in a transaction for atomicity (rollback on any failure)
- [x] 1.3 Add migration function to `api/internal/db/db.go` for `oak_entries` → `species` table (rename + add ID)
- [x] 1.4 Add migration function to `api/internal/db/db.go` for `taxa` table
- [x] 1.5 Add migration function to `api/internal/db/db.go` for `species_sources` table (scientific_name → species_id)
- [x] 1.6 Mirror schema changes in `cli/internal/db/db.go`
- [x] 1.7 Add migration tests with sample data
- [x] 1.8 Test migration on copy of production database

## 2. API Model Updates

- [x] 2.1 Rename `OakEntry` model to `Species` in `api/internal/models/`
- [x] 2.2 Add `ID` field to `Species` model
- [x] 2.3 Add `ID` field to `Taxon` model
- [x] 2.4 Update all handler references from `OakEntry` to `Species`
- [x] 2.5 Update JSON serialization to include `id` field in responses
- [x] 2.6 Mirror model changes in CLI if needed

## 3. API Handler Updates

- [x] 3.1 Add `GET /api/v1/species/id/{id}` endpoint
- [x] 3.2 Add `GET /api/v1/taxa/id/{id}` endpoint
- [x] 3.3 Update species handlers to populate ID field
- [x] 3.4 Update taxa handlers to populate ID field
- [x] 3.5 Add handler tests for new ID-based routes

## 4. Database Query Updates

- [x] 4.1 Update all SQL queries to use `species` table name instead of `oak_entries`
- [x] 4.2 Update `GetSpecies` to return ID
- [x] 4.3 Update `ListSpecies` to return IDs
- [x] 4.4 Update `GetTaxon` to return ID
- [x] 4.5 Update `ListTaxa` to return IDs
- [x] 4.6 Add `GetSpeciesByID` function
- [x] 4.7 Add `GetTaxonByID` function
- [x] 4.8 Update `species_sources` queries to use `species_id` instead of `scientific_name`
- [x] 4.9 Update `species_sources` handlers to resolve name → ID before DB operations
- [x] 4.10 Fix `SaveSpeciesSource` to use `ON CONFLICT(species_id, source_id) DO UPDATE` instead of `INSERT OR REPLACE` (fixes oaks-7sfz)

## 5. Cleanup

- [x] 5.1 Update CLAUDE.md documentation if schema section needs changes
- [x] 5.2 Close beads issue `oaks-7sfz` after bug fix is verified

## 6. Verification

- [x] 6.1 Verify web app works with new `id` fields in responses (should ignore them)
- [x] 6.2 Test species rename still works end-to-end

## 7. Deployment

- [x] 7.1 Deploy API with migration to staging/test
- [x] 7.2 Verify migration completed successfully
- [x] 7.3 Deploy to production
- [x] 7.4 Verify production migration
