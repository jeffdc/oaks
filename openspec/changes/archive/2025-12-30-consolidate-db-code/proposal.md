# Change: Consolidate Duplicated Database Code Between CLI and API

## Why

The `refactor-cli-api-split` change (copy/paste from CLI to API) created significant code duplication:

- **~1,000+ lines of duplicated code** across `cli/internal/db/` and `api/internal/db/`
- **38+ duplicated functions** with identical implementations
- **Identical models** duplicated in `cli/internal/models/` and `api/internal/models/`
- **Critical bug**: API's `SaveOakEntry()` is missing bidirectional parent-child relationship management that CLI has (when saving a hybrid, CLI updates parent species' `hybrids` lists; API doesn't)

This duplication is a maintenance nightmare and has already introduced data consistency bugs.

## Approach Options

### Option A: Shared Package (Minimal Change)

Create `pkg/db/` and `pkg/models/` used by both CLI and API via Go workspace.

**Pros:**
- Minimal architectural change
- Both CLI and API can still operate independently
- CLI keeps fast local-only operations (bulk imports)

**Cons:**
- Still two codepaths (local vs remote)
- Must maintain both db and client code

### Option B: API-Only Database (Recommended)

API owns all database operations. CLI becomes a pure API client.

**Pros:**
- Single source of truth for all database logic
- No code duplication
- Guarantees data consistency
- Simpler mental model

**Cons:**
- CLI requires network access (or embedded API for offline)
- Bulk imports go through HTTP (slower for large datasets)
- API becomes critical dependency

### Recommendation: Option B with Local API Mode

CLI embeds the API server for local operations:
- `oak --local` spawns embedded API on localhost, uses it, shuts down
- `oak --profile prod` uses remote API
- All database logic lives in `api/internal/db/` only
- CLI only has `internal/client/` for HTTP operations

## What Changes

### Code Removal
- **REMOVED**: `cli/internal/db/` (~1,400 lines)
- **REMOVED**: `cli/internal/models/` (duplicated models)
- **MODIFIED**: CLI commands use API client for all operations

### API Enhancement
- **FIXED**: `api/internal/db/SaveOakEntry()` gains bidirectional relationship management (from CLI version)
- **ADDED**: Bulk import endpoint for large datasets (optional, for performance)

### CLI Simplification
- **MODIFIED**: All commands use `internal/client/` exclusively
- **ADDED**: Embedded API mode for `--local` operations
- **REMOVED**: Direct database access

## Impact

- **Affected specs**: api-server (add bulk endpoint, fix SaveOakEntry)
- **Affected code**:
  - `cli/internal/db/` - DELETED
  - `cli/internal/models/` - DELETED
  - `cli/cmd/*.go` - Use client instead of db
  - `api/internal/db/db.go` - Fix SaveOakEntry
- **Breaking changes**: None for end users
- **Lines removed**: ~2,500 (db.go + models.go in CLI, plus tests)

## Current Bug: Missing Relationship Management

**CLI version** (`cli/internal/db/db.go:471-529`):
```go
func (db *DB) SaveOakEntry(entry *models.OakEntry) error {
    tx, _ := db.conn.Begin()
    // Get old entry to track parent changes
    oldEntry, _ := db.getOakEntryTx(tx, entry.ScientificName)

    // Remove from old parents' hybrids lists
    if oldEntry != nil && oldEntry.Parent1 != entry.Parent1 {
        db.removeHybridFromParentTx(tx, oldEntry.Parent1, entry.ScientificName)
    }
    // Add to new parents' hybrids lists
    if entry.Parent1 != "" {
        db.addHybridToParentTx(tx, entry.Parent1, entry.ScientificName)
    }
    // ... (same for Parent2)
    tx.Commit()
}
```

**API version** (`api/internal/db/db.go:448-493`):
```go
func (db *DB) SaveOakEntry(entry *models.OakEntry) error {
    // MISSING: No transaction
    // MISSING: No parent relationship tracking
    // Just marshals JSON and does INSERT OR REPLACE
}
```

This bug means hybrids created/updated via API won't appear in their parents' `hybrids` lists.
