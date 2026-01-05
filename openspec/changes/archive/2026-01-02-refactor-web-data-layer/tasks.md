# Tasks: Web Data Layer Refactor

## Phase 1: API Additions (Non-Breaking)

### 1. Full Species Endpoint

- [x] 1.1 Add `SpeciesWithSources` response model (species fields + embedded sources array)
- [x] 1.2 Implement `handleGetSpeciesFull` handler
- [x] 1.3 Query species and sources in single handler (avoid N+1)
- [x] 1.4 Include source metadata (name, URL) from sources table
- [x] 1.5 Order sources by is_preferred DESC, source_id ASC
- [x] 1.6 Register route `GET /api/v1/species/{name}/full`
- [x] 1.7 Handle 404 for non-existent species
- [x] 1.8 Add tests for full species endpoint

### 2. Delete Cascade Protection

- [x] 2.1 Add query to find hybrids referencing a species as parent1 or parent2
- [x] 2.2 Update `handleDeleteSpecies` to check for referencing hybrids before delete
- [x] 2.3 Return 409 Conflict with blocking hybrids list if found
- [x] 2.4 Add tests for cascade protection (both allowed and blocked cases)

### 3. Gzip Compression

- [x] 3.1 Add gzip middleware to API server
- [x] 3.2 Configure minimum size threshold (e.g., 1KB)
- [x] 3.3 Verify compression on large responses
- [x] 3.4 Verify small responses are not compressed

### 4. Deploy API (Phase 1)

- [x] 4.1 Run API tests locally
- [x] 4.2 Deploy to Fly.io
- [x] 4.3 Verify new endpoint works in production
- [x] 4.4 Verify gzip compression in production

## Phase 2: Web App Changes

### 5. Remove Client-Side Persistence

- [x] 5.1 Remove `dexie` from package.json
- [x] 5.2 Delete `src/lib/db.js`
- [x] 5.3 Delete `static/quercus_data.json`
- [x] 5.4 Remove all imports of db.js
- [x] 5.5 Run npm install to clean dependencies

### 6. API Client Updates

- [x] 6.1 Add `fetchSpeciesFull(name)` function
- [x] 6.2 Add retry logic helper with exponential backoff
- [x] 6.3 Remove format conversion functions (`speciesToApiFormat`, etc.) — do after Task 12
- [x] 6.4 Remove `fetchExport()` function
- [x] 6.5 Update error handling for API failures
- [x] 6.6 Add tests for retry logic

### 7. Data Store Simplification

- [x] 7.1 Remove global `allSpecies` store
- [x] 7.2 Remove global `allSources` store
- [x] 7.3 Remove `loadSpeciesData()` function
- [x] 7.4 Remove `refreshData()` function
- [x] 7.5 Remove all IndexedDB-related code
- [x] 7.6 Keep simple derived stores if needed (e.g., search query)

### 8. Species List Component

- [x] 8.1 Add local state for species list
- [x] 8.2 Fetch `GET /api/v1/species` on mount
- [x] 8.3 Add loading spinner during fetch
- [x] 8.4 Add error state for failed fetch
- [x] 8.5 Update to use `scientific_name` field

### 9. Species Detail Component

- [x] 9.1 Add local state for species detail
- [x] 9.2 Fetch `GET /api/v1/species/{name}/full` on mount
- [x] 9.3 Add loading spinner during fetch
- [x] 9.4 Add error state for failed fetch / 404
- [x] 9.5 Update to use API format fields (scientific_name, flat taxonomy)
- [x] 9.6 Update source display to use embedded sources

### 10. Taxonomy Browser Component

- [x] 10.1 Add local state for taxa
- [x] 10.2 Fetch `GET /api/v1/taxa` on mount
- [x] 10.3 Add loading spinner during fetch
- [x] 10.4 Add error state for failed fetch

### 11. Search Component

- [x] 11.1 Update to use `GET /api/v1/species/search?q=...`
- [x] 11.2 Add debouncing for search input
- [x] 11.3 Add loading state during search
- [x] 11.4 Update results display for API format
- [x] 11.5 Cancel pending search requests when new search starts (prevent race conditions)

### 12. Edit Forms

- [x] 12.1 Update species edit to fetch sources for dropdown (`GET /api/v1/sources`)
- [x] 12.2 Update species-source edit form for API format
- [x] 12.3 Update taxon edit form for API format
- [x] 12.4 Update source edit form (no format changes needed)

### 13. Edit Flow Updates

- [x] 13.1 After save: refetch current view's data with retry
- [x] 13.2 After create: navigate to detail view (which fetches fresh)
- [x] 13.3 After delete: navigate to list view (which fetches fresh)
- [x] 13.4 Handle 409 Conflict for blocked species deletion
- [x] 13.5 Show blocking hybrids in error dialog
- [x] 13.6 Add toast for "edit saved but display stale" case

### 14. Error Handling

- [x] 14.1 Add "Unable to connect" message for API failures
- [x] 14.2 Add retry button on error states
- [x] 14.3 Handle network errors gracefully
- [x] 14.4 Remove offline detection code (no longer relevant)

### 15. Deploy Web App

- [x] 15.1 Run web tests locally
- [x] 15.2 Test all views manually (list, detail, taxonomy, search)
- [x] 15.3 Test all edit flows (create, update, delete)
- [x] 15.4 Test delete cascade error handling
- [x] 15.5 Deploy to production

## Phase 3: API Cleanup (Breaking)

### 16. Remove Export Endpoint

- [x] 16.1 Delete `handleExport` handler
- [x] 16.2 Remove route registration for `/api/v1/export`
- [x] 16.3 Delete export-related tests
- [x] 16.4 Deploy to production

## Phase 4: Documentation

### 17. Update Documentation

- [x] 17.1 Update CLAUDE.md data flow diagram
- [x] 17.2 Update CLAUDE.md architecture section
- [x] 17.3 Update web/CLAUDE.md with new data flow
- [x] 17.4 Remove references to IndexedDB, offline support, quercus_data.json
- [x] 17.5 Document fetch-per-view pattern

## Integration Testing Checklist

After all phases complete:

- [x] Species list loads and displays correctly
- [x] Species detail loads with embedded sources
- [x] Taxonomy browser loads and navigates
- [x] Search returns results from API
- [x] Create species works and navigates to detail
- [x] Edit species works and refreshes data
- [x] Delete species works (with cascade protection)
- [x] Delete blocked shows hybrids list
- [x] API errors show user-friendly messages
- [x] Retry logic works for transient failures
- [x] Gzip compression reduces response sizes
