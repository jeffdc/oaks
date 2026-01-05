# Design: Add Integer IDs to Tables

## Context

The current schema has two tables with non-integer primary keys:

```sql
-- Current taxa table
CREATE TABLE taxa (
    name TEXT NOT NULL,
    level TEXT NOT NULL,
    parent TEXT,
    ...
    PRIMARY KEY (name, level)
);

-- Current oak_entries table
CREATE TABLE oak_entries (
    scientific_name TEXT PRIMARY KEY,
    ...
);
```

This causes issues:
1. **FK references are awkward**: To reference a taxon, you need both name and level
2. **Name changes break references**: Renaming a species requires updating all FKs
3. **API routes are clunky**: `/api/v1/taxa/section/Quercus` vs `/api/v1/taxa/42`

## Goals

- Add stable integer IDs to `taxa` and `oak_entries`
- Maintain backward compatibility (name-based lookups still work)
- Enable future improvements (ID-based FKs, simpler joins)

## Non-Goals

- Full schema normalization (separate taxonomy tables)
- Removing name-based primary keys entirely

## Decisions

### Decision 1: Add ID column, keep composite/text key as UNIQUE

For `taxa`:
```sql
ALTER TABLE taxa ADD COLUMN id INTEGER;
-- Then migrate to new schema with id as PK, (name, level) as UNIQUE
```

For `oak_entries` (renamed to `species`):
```sql
-- Migrate to new table named 'species' with id as PK, scientific_name as UNIQUE
```

**Rationale**: SQLite doesn't support adding PRIMARY KEY to existing tables. We'll need to:
1. Create new table with correct schema
2. Copy data with generated IDs
3. Drop old table, rename new

### Decision 5: Rename `oak_entries` to `species`

**Rationale**: The API already uses `/api/v1/species/...` routes. The table name should match for consistency. "species" is also more accurate and self-explanatory than "oak_entries".

### Decision 6: Rename `OakEntry` model to `Species`

**Rationale**: The Go model name should match the table name for consistency. All references to `OakEntry` in handlers, tests, and other code will be updated to `Species`.

### Decision 2: Name routes are primary, ID routes are supplementary

Name-based routes are the **permanent primary interface**:
- `GET /api/v1/species/alba` - by name (primary)
- `GET /api/v1/taxa/section/Quercus` - by level/name (primary)

ID routes added for internal/programmatic use:
- `GET /api/v1/species/id/123` - by ID (supplementary)
- `GET /api/v1/taxa/id/42` - by ID (supplementary)

**Rationale**: Human-readable URLs are better UX. `/species/alba` is easier to share, bookmark, and understand than `/species/id/47`. IDs exist for stable references in code and data, not as the primary access pattern.

### Decision 3: Use AUTOINCREMENT

```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
```

**Rationale**: Ensures IDs are never reused after deletion, which is important for external references.

### Decision 4: Migrate `species_sources` FK to use `species_id`

Current:
```sql
CREATE TABLE species_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scientific_name TEXT NOT NULL,
    source_id INTEGER NOT NULL,
    ...
    FOREIGN KEY (scientific_name) REFERENCES oak_entries(scientific_name),
    UNIQUE(scientific_name, source_id)
);
```

After migration:
```sql
CREATE TABLE species_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    species_id INTEGER NOT NULL,
    source_id INTEGER NOT NULL,
    ...
    FOREIGN KEY (species_id) REFERENCES oak_entries(id),
    UNIQUE(species_id, source_id)
);
```

**Rationale**: This is the main benefit of adding IDs - species can be renamed without breaking source data relationships. API routes remain name-based (`/api/v1/species/alba/sources`), but internally the DB uses stable integer FKs.

## Migration Plan

**IMPORTANT**: Migration MUST be idempotent (safe to run multiple times). This is critical for server restarts, multiple app instances, and recovery from partial failures.

1. **Add migration code** in `db.go` that:
   - Checks if tables have `id` column (skip if already migrated)
   - If not, creates new tables with `id` as PK
   - Copies data, generating sequential IDs
   - Drops old tables, renames new ones

2. **Order of operations** (must be sequential due to FK dependencies):
   1. **Pre-flight check**: Verify no orphaned `species_sources` rows exist (scientific_name not in oak_entries). Fail migration if any found.
   2. Migrate `oak_entries` → `species` - rename table, add `id` column as PK
   3. Migrate `taxa` - add `id` column as PK
   4. Migrate `species_sources` - replace `scientific_name` with `species_id` FK
      - Join on `scientific_name` to look up the new `id` from `species`
      - Update unique constraint from `(scientific_name, source_id)` to `(species_id, source_id)`

3. **Transaction**: Wrap entire migration in a transaction for atomicity. If any step fails, rollback all changes.

4. **Rollback**: Keep backup of database before migration. Migration is one-way (no downgrade path).

## Schema After Migration

```sql
CREATE TABLE taxa (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    level TEXT NOT NULL CHECK(level IN ('subgenus', 'section', 'subsection', 'complex')),
    parent TEXT,
    author TEXT,
    content TEXT,
    content_updated_at TEXT,
    links TEXT,
    UNIQUE(name, level)
);

CREATE TABLE species (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scientific_name TEXT NOT NULL UNIQUE,
    author TEXT,
    is_hybrid INTEGER NOT NULL DEFAULT 0,
    conservation_status TEXT,
    subgenus TEXT,
    section TEXT,
    subsection TEXT,
    complex TEXT,
    parent1 TEXT,
    parent2 TEXT,
    hybrids TEXT,
    closely_related_to TEXT,
    subspecies_varieties TEXT,
    synonyms TEXT,
    external_links TEXT
);

CREATE TABLE species_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    species_id INTEGER NOT NULL,
    source_id INTEGER NOT NULL,
    local_names TEXT,
    range TEXT,
    growth_habit TEXT,
    leaves TEXT,
    flowers TEXT,
    fruits TEXT,
    bark TEXT,
    twigs TEXT,
    buds TEXT,
    hardiness_habitat TEXT,
    miscellaneous TEXT,
    url TEXT,
    is_preferred INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (species_id) REFERENCES species(id) ON DELETE CASCADE,
    FOREIGN KEY (source_id) REFERENCES sources(id),
    UNIQUE(species_id, source_id)
);

-- Indexes (recreated during migration)
CREATE INDEX idx_species_sources_species ON species_sources(species_id);
CREATE INDEX idx_species_sources_source ON species_sources(source_id);
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Migration corrupts data | Test on copy first, keep backup |
| API clients break | Name routes unchanged, ID routes are additive |
| Performance impact | IDs improve join performance (integers vs text) |

## Open Questions

None - all questions resolved.
