# Change: Refactor Web Data Layer to Stateless Fetch-Per-View

## Branch

**IMPORTANT**: This work is intentionally separate from the `web-editing` branch to avoid entanglement.

1. Create new branch `refactor-data-layer` directly off `main`
2. Implement and test all changes on this branch
3. Merge to `main` and deploy to production
4. Then merge `main` into `web-editing` to bring the refactor into that branch

The web-editing work exposed severe bugs in the current cache implementation, motivating this refactor. However, we keep the branches separate to test the refactor in isolation.

## Why

The current web app data architecture is overly complex:

1. **Full refresh on every edit**: After any edit, the app fetches the entire export (~1-2MB), clears IndexedDB, and repopulates everything. This is slow and creates race conditions.

2. **Export as sync mechanism**: The `/api/v1/export` endpoint was designed for initial data population, but it's being used for sync after edits. This conflates two different concerns.

3. **Format conversion overhead**: Data converts between export format (nested taxonomy, embedded sources) and API format (flat fields, separate endpoints), requiring manual mapping in multiple places.

4. **IndexedDB adds complexity without benefit**: The current design treats IndexedDB as a synchronized database that must match the server. This adds complexity for cache invalidation, staleness detection, and consistency—all for offline support that isn't actually needed.

5. **Static JSON file is redundant**: The `quercus_data.json` file duplicates what the API provides and requires manual export/commit cycles.

## What Changes

### Core Architecture Shift

**FROM**: Export-driven sync (fetch full export, populate IndexedDB, read from IndexedDB)

**TO**: Stateless fetch-per-view (each component fetches exactly what it needs, no client-side persistence)

### API Changes (`api/`)

**ADDED**: `GET /api/v1/species/{name}/full`
- Returns single species with embedded sources
- Used by species detail view
- Flat field format (matches other API endpoints)

**ADDED**: Gzip compression
- All JSON responses compressed
- ~80-90% size reduction for large payloads

**ADDED**: Delete cascade protection
- Species deletion blocked (409) if referenced as hybrid parent
- Response includes list of blocking hybrids

**REMOVED**: `GET /api/v1/export`
- No longer needed; individual endpoints serve each view
- CLI has its own export command (doesn't use API)

### Web Changes (`web/`)

**MODIFIED**: Data loading strategy
- Each component fetches its own data on mount
- Species list: `GET /api/v1/species`
- Species detail: `GET /api/v1/species/{name}/full`
- Taxonomy browser: `GET /api/v1/taxa`
- Edit forms: `GET /api/v1/sources` (for dropdowns)
- Search: `GET /api/v1/species/search?q=...`
- No shared "all data" store

**MODIFIED**: Edit save flow
- Save: API call (PUT/POST/DELETE)
- On success: Refetch the current view's data
- Retry logic: 2-3 attempts with backoff for transient failures

**REMOVED**: IndexedDB entirely
- No more Dexie.js dependency
- No cache invalidation logic
- No staleness detection

**REMOVED**: Format conversion functions
- No more `speciesToApiFormat()`, `apiFormatToWeb()`, etc.
- UI components updated to work with API format directly

**REMOVED**: `quercus_data.json` static file
- No longer needed; all data comes from API

**REMOVED**: Global data stores
- No `allSpecies` store holding everything
- Each component manages its own loading state

### Offline Behavior

- **Not supported** (explicitly out of scope)
- Show "Unable to connect" message if API unavailable
- Caching/PWA will be a separate future initiative

### Edit Recovery Strategy

If edit API call succeeds but follow-up GET fails:
1. Retry GET 2-3 times with exponential backoff
2. If still failing: Show toast "Edit saved but display may be stale—refresh to see changes."
3. On next navigation or refresh, data will be current

## Impact

- **Affected specs**: api-server (new endpoint, remove export)
- **Affected code**:
  - `api/internal/handlers/` - new full species endpoint, gzip, delete protection
  - `api/internal/handlers/export.go` - removed
  - `web/src/lib/db.js` - removed entirely
  - `web/src/lib/stores/dataStore.js` - simplified to per-component fetching
  - `web/src/lib/apiClient.js` - remove format conversion, add retry logic
  - `web/src/lib/components/*.svelte` - fetch on mount, use API format
  - `web/static/quercus_data.json` - removed
  - `web/package.json` - remove dexie dependency
- **Breaking changes**:
  - `/api/v1/export` removed (was only used by web app)
  - Offline support removed (was never fully working anyway)

## Goals

1. **Simplify**: One data format (API format), no client-side persistence
2. **Reliability**: No race conditions, no cache invalidation bugs
3. **Maintainability**: Much less code, no IndexedDB, no format conversions
4. **Clarity**: Each component is self-contained with its own data fetching

## Non-Goals

- Offline support (separate future initiative for read-side caching/PWA)
- Real-time sync between tabs/devices
- Optimistic UI updates
- Client-side caching of any kind

## Dependencies

- **Branches from**: `main` - Clean slate, no entanglement with web-editing
- **Merges into**: `main` - Deploy to production first
- **Then**: Merge `main` into `web-editing` to bring refactor into that branch

## Future: Adding Caching/PWA

When caching becomes a priority, it will be a separate initiative that:
1. Adds service worker for read-side caching
2. Implements proper cache invalidation strategy
3. Adds offline indicators and graceful degradation
4. Does not affect the core fetch-per-view architecture

This keeps the current refactor focused on simplicity.
