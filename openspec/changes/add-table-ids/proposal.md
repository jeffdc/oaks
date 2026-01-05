# Change: Add Integer IDs to Taxa and Oak Entries Tables

## Why

Two tables use non-integer primary keys which causes problems:
- `taxa`: Uses composite key `(name, level)` - awkward for FK references, ugly API URLs
- `oak_entries`: Uses `scientific_name TEXT` - if species name changes (taxonomic revision, typo), all FK references break

Integer IDs provide stable identifiers that don't change when the data they represent changes.

## What Changes

- **Database schema**: Add `id INTEGER PRIMARY KEY AUTOINCREMENT` to `taxa` and `oak_entries` tables
- **Database schema**: Rename `oak_entries` table to `species` (matches API naming)
- **Database schema**: Migrate `species_sources.scientific_name` to `species_sources.species_id` (integer FK)
- **API**: Add optional ID-based lookups alongside existing name-based routes
- **CLI/API code**: Update to handle new ID columns, FK changes, table rename, and model rename (`OakEntry` → `Species`)
- **Migration**: Populate IDs for existing rows, convert `species_sources` FK, rename table
- **Bug fix**: Fix `SaveSpeciesSource` to use `ON CONFLICT DO UPDATE` instead of `INSERT OR REPLACE` (closes `oaks-7sfz`)

**Note**: This change keeps:
- Existing table structure (no normalization)
- JSON arrays in text columns (synonyms, hybrids, etc.)
- Name-based API routes (IDs are additive, not replacing)

## Impact

- Affected specs: `api-server`
- Affected code:
  - `api/internal/db/db.go` - Schema changes, query updates, FK migration
  - `cli/internal/db/db.go` - Schema changes (mirrored)
  - `api/internal/handlers/*.go` - New ID-based endpoints, populate ID fields
  - `api/internal/models/*.go` - Add ID fields to OakEntry and Taxon models
- Web app: **No changes required** - will receive `id` field in responses but can ignore until images feature needs it

## Non-Goals

- Full schema normalization (separate tables for taxonomy hierarchy)
- Replacing name-based lookups - name routes are the **permanent primary interface** (human-readable URLs are better UX)
- Breaking existing API clients (additive changes only)

## Enables

- **add-species-images**: The images table uses `species_id` as FK, requiring stable integer IDs
