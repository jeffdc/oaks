# Change: Replace Bear Note Sync with iOS App via API

## Why

The current workflow uses Bear app (macOS/iOS) for field note capture, with `oak import-bear` reading Bear's SQLite database directly. This approach has limitations:

- Requires Bear app ($15 subscription) and macOS for import
- Complex markdown parsing to extract structured fields
- No photo support (Bear notes can have images, but CLI doesn't import them)
- One-way sync only (CLI cannot push data back to Bear)
- Bear's tag-based taxonomy is error-prone

The in-development iOS app (`ios/OakCompendium`) already has structured note capture with taxonomy pickers, dedicated field editors, and photo support. Combined with the planned API server, we can provide real-time sync between iOS and the central database.

## Related Work

- **Depends on**: OpenSpec change `add-crud-api-server` (API specification and implementation)
- **Replaces**: Bear app workflow

## What Changes

### CLI (`cli/`)
- **REMOVED**: `oak import-bear` command (`cmd/import_bear.go`)
- **REMOVED**: `oak generate-bear-notes` command (`cmd/generate_bear_notes.go`)
- **ADDED**: `oak serve` command to run API server (covered by `add-crud-api-server`)
- **ADDED**: Notes CRUD endpoints: `GET/POST/PUT/DELETE /api/v1/notes` (convenience layer over species_sources for source_id 3)
- **MODIFIED**: Documentation and CLAUDE.md to reflect new workflow

### iOS App (`ios/OakCompendium/`)
- **ADDED**: `APIService.swift` to communicate with API server
- **ADDED**: Offline caching with background sync
- **MODIFIED**: `NotesViewModel` to use API instead of local-only storage
- **MODIFIED**: Species browsing to fetch from API

### Documentation
- **MODIFIED**: CLAUDE.md data flow diagram (remove Bear, add API server)
- **REMOVED**: Bear workflow documentation
- **ADDED**: API-based sync workflow documentation

## Impact

- **Affected specs**: note-sync (new capability)
- **Affected code**:
  - `cli/cmd/import_bear.go` (delete)
  - `cli/cmd/generate_bear_notes.go` (delete)
  - `cli/cmd/serve.go` (new - covered by `add-crud-api-server`)
  - `cli/internal/api/` (new - API handlers)
  - `ios/OakCompendium/Sources/Services/APIService.swift` (new)
  - `ios/OakCompendium/Sources/Services/StorageService.swift` (modify for caching)
  - `CLAUDE.md`
- **Breaking changes**: Users relying on Bear workflow will need to migrate notes manually
- **Data migration**: Existing Bear notes should be imported one final time before removing Bear commands

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │     │   Web App       │     │   CLI           │
│ OakCompendium   │     │   (Svelte)      │     │   (oak)         │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │ HTTPS                 │ HTTPS                 │ direct
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     oak serve (API Server)                      │
│                     GET/POST/PUT/DELETE                         │
│                  /api/v1/species, /api/v1/notes, /api/v1/taxa   │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   oak_compendium.db     │
                    │       (SQLite)          │
                    └─────────────────────────┘
```
